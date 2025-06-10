package tencentcloud

import (
	"regexp"
	"strings"
)

tcr: {
	#var: {
		name: string
		args: {
			vpc_name:          string
			subnet_name:       string
			availability_zone: string
		}
	}

	#tencentcloud: {
		private_dns: domain: _
		dnspod: domain:      _
		tcr: {
			customized_domain: args: {...}
			instance: args: {...}
			vpc_attachment: args: {...}
			namespace: [n=string]: {
				args: {
					// 长度2 - 30个字符，只能包含小写字母、数字及分隔符("."、"_"、"-")，且不能以分隔符开头、结尾或连续
					name: *n | _
					...
				}
				repository: [r=string]: args: {
					name: *r | _
					...
				}
			}
		}
	}

	let N = #var.name

	resource: tencentcloud_tcr_instance: (N): #tencentcloud.tcr.instance.args & {
		name:                  N
		instance_type:         *"basic" | "standard" | "premium"
		open_public_operation: *false | true
	}

	resource: tencentcloud_private_dns_record: (N): {
		record_type:  "CNAME"
		sub_domain:   N
		record_value: "${tencentcloud_tcr_instance.\(N).public_domain}"
	}

	resource: tencentcloud_tcr_vpc_attachment: (N): #tencentcloud.tcr.vpc_attachment.args & {
		instance_id:              "${tencentcloud_tcr_instance.\(N).id}"
		vpc_id:                   "${local.vpc_id}"
		subnet_id:                *"${local.subnet_id}" | _
		enable_public_domain_dns: true
		enable_vpc_domain_dns:    true
	}

	resource: tencentcloud_tcr_customized_domain: (N): #tencentcloud.tcr.customized_domain.args & {
		registry_id: "${tencentcloud_tcr_instance.\(N).id}"
		// TODO(yujunz): bind default
		domain_name:    _
		certificate_id: _
	}

	for n, ns in #tencentcloud.tcr.namespace {
		let NS = strings.Replace("\(N)_\(n)", ".", "_", -1)
		resource: tencentcloud_tcr_namespace: (NS): ns.args & {
			instance_id: "${tencentcloud_tcr_instance.\(N).id}"
		}

		for r, repo in ns.repository {
			let REPO = regexp.ReplaceAll("[^a-zA-Z0-9_\\-]", "\(NS)_\(r)", "_")
			resource: tencentcloud_tcr_repository: (REPO): repo.args & {
				instance_id:    "${tencentcloud_tcr_instance.\(N).id}"
				namespace_name: "${tencentcloud_tcr_namespace.\(NS).name}"
			}
		}
	}

	resource: tencentcloud_tcr_service_account: (N): {
		name:        N
		registry_id: "${tencentcloud_tcr_instance.\(N).id}"
		duration:    *-1 | _
		permissions: {
			actions: ["tcr:PullRepository"]
			resource: "*"
		}
	}
}
