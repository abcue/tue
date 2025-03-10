package tencentcloud

import (
	"list"
	"regexp"
	"strings"
)

dnspod: {
	#var: {
		dnspod: {
			domain: *"" | string
			sub_domains: *[] | [...string]
			// a creates a record resolving to IPv4 addresses
			// a: [record]: =ipv4 | [...ipv4]
			// e.g.
			// a: {
			// 	maglev: "100.65.0.4"
			//  swiftstack: ["100.65.0.2", "100.65.0.3"]
			// }
			record: {
				a: *{} | {[string]: string | [...string]}
				cname: {
					// "maglev.cn.nvda.ai": "cache.maglev": _
					// cache.maglev.cn.nvda.ai CNAME maglev.cn.nvda.ai
					[record_value=string]: [sub_domain=string]: _
				}
				srv: *{} | {[string]: string}
			}
		}
	}
	_local: rsc_replace: "[^0-9a-zA-Z_\\-]"
	let D = #var.dnspod.domain
	for type, records in #var.dnspod.record {
		for record, value in records for v in list.FlattenN([value], -1) {
			let R = regexp.ReplaceAllLiteral(_local.rsc_replace, strings.Join([D, record, type], "_"), "_")
			resource: tencentcloud_dnspod_record: (R): {
				domain:      D
				sub_domain:  record
				record_type: type
				value:       v
			}
		}
	}
	_local: import: {}
	for sd in #var.dnspod.sub_domains {
		let SD = "\(sd).\(D)"
		let SDN = regexp.ReplaceAllLiteral(_local.rsc_replace, SD, "_")

		// // Easier to validate interactively in console then import
		// resource: tencentcloud_subdomain_validate_txt_value_operation: (SDN): domain_zone: SD
		_local: import: (SD): {
			id: SD
			to: "tencentcloud_dnspod_domain_instance.\(SDN)"
		}
		resource: tencentcloud_dnspod_domain_instance: (SDN): domain: SD
	}
	import: [for _, imp in _local.import {imp}]
}
