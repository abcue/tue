package aws

import (
	"encoding/json"
	"list"
	"net"
)

wafv2: {
	#var: {
		name:    string
		product: "wafv2"
	}

	let N = #var.name

	#aws: wafv2: {
		reqs: {
			scope: *"CLOUDFRONT" | "REGIONAL"
			rulegroups: {
				[name=_]: {
					priority: int
					arn:      string
				}
				if resource.aws_wafv2_rule_group[N] != _|_ {
					(N): {
						priority: 10
						arn:      "${aws_wafv2_rule_group.\(N).arn}"
					}
				}
			}
		}
		args: visibility_config: {
			cloudwatch_metrics_enabled: false
			sampled_requests_enabled:   false
		}
		ip_set: reqs: [name=_]: {
			#json?:   _
			priority: int
			version: IPV4: [...(net.IPCIDR | net.IPv4)]
			if #json != _|_ {
				// TODO(yujunz): implement ipv4 sorting
				version: IPV4: list.Sort(list.Concat([for ip_list in #json {ip_list}]), list.Ascending)
			}
		}

		rule_group: reqs: allow: aws: account: [alias=_]: id: string
	}

	provider: aws: region: _

	for n, ip_set in #aws.wafv2.ip_set.reqs {
		let fn = N + "_" + n
		resource: aws_wafv2_ip_set: (fn): {
			name:  fn
			scope: #aws.wafv2.reqs.scope
			for version, addresses in ip_set.version {
				ip_address_version: version
				"addresses": [for address in addresses {
					if (address & net.IPCIDR) == _|_ {
						address + "/32"
					}
					if (address & net.IPCIDR) != _|_ {
						address
					}
				}]
			}
		}
	}

	resource: aws_wafv2_rule_group?: (N)?: {
		name:     N
		scope:    #aws.wafv2.reqs.scope
		capacity: 100
		rule: [for n, ip_set in #aws.wafv2.ip_set.reqs {
			let fn = N + "_" + n
			name:     n
			priority: ip_set.priority
			action: allow: {}
			statement: ip_set_reference_statement: arn: "${aws_wafv2_ip_set.\(fn).arn}"
			visibility_config: {
				#aws.wafv2.args.visibility_config
				metric_name: fn + "_wafv2_rule"
			}
		}]
		visibility_config: {
			#aws.wafv2.args.visibility_config
			metric_name: N + "_wafv2_rule_group"
		}
	}

	resource: aws_wafv2_web_acl: (N): {
		name:  N
		scope: #aws.wafv2.reqs.scope
		default_action: block: {}
		rule: [
			for n, rulegroup in #aws.wafv2.reqs.rulegroups {
				name:     n
				priority: rulegroup.priority
				override_action: none: {}
				statement: rule_group_reference_statement: arn: rulegroup.arn
				visibility_config: {
					#aws.wafv2.args.visibility_config
					metric_name: n + "_wafv2_rule"
				}
			},
		]
		visibility_config: {
			#aws.wafv2.args.visibility_config
			metric_name: N + "_wafv2_web_acl"
		}
	}

	if resource.aws_wafv2_rule_group[N] != _|_ {
		output: wafv2_put_permission_policy: {
			// https://docs.aws.amazon.com/waf/latest/APIReference/API_PutPermissionPolicy.html
			let JSON = json.Marshal({
				Version: "2012-10-17"
				Statement: [{
					Effect: "Allow"
					Principal: AWS: [for account_alias, account in #aws.wafv2.rule_group.reqs.allow.aws.account {
						"arn:aws:iam::\(account.id):root"
					}]
					Action: [
						"wafv2:CreateWebACL",
						"wafv2:UpdateWebACL",
						"wafv2:PutFirewallManagerRuleGroups",
						"wafv2:GetRuleGroup",
					]
				}]
			})
			value: "aws wafv2 put-permission-policy --region \(provider.aws.region) --resource-arn ${aws_wafv2_rule_group.\(N).arn} --policy '\(JSON)'"
		}
	}
}
