package aws

import "net"

waf: {
	#var: {
		name:    string
		product: "waf"
	}

	let N = #var.name

	#aws: waf: ipset: reqs: [ipset_name=_]: IPV4: [...(net.IPCIDR | net.IPv4)]

	for n, ipsets in #aws.waf.ipset.reqs {
		resource: aws_waf_ipset: (N + "_" + n): {
			name: N + " " + n
			ip_set_descriptors: [for type, addresses in ipsets for address in addresses {
				"type": type
				if (address & net.IPCIDR) == _|_ {
					value: address + "/32"
				}
				value: *address | _
			}]
		}
	}
}
