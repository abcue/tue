package tencentcloud

import (
	"list"
	"regexp"
	"strings"
)

dnspod: {
	#tencentcloud: dnspod: {
		domain: string
		sub_domains: *[] | [...string]
		record: {
			// a creates a record resolving to IPv4 addresses
			// a: [record]: =ipv4 | [...ipv4]
			a: *{} | {[sub_domain=string]: string | [...string]}
			cname: *{} | {[value=string]: [sub_domain=string]: _}
			srv: *{} | {[string]: string}
		}
	}

	let R = "[^0-9a-zA-Z_\\-]"
	let D = #tencentcloud.dnspod.domain
	let DN = regexp.ReplaceAllLiteral(R, D, "_")

	resource: tencentcloud_dnspod_domain_instance?: (DN)?: domain: D
	_local: import: {
		if resource.tencentcloud_dnspod_domain_instance[DN] != _|_ {
			(D): {
				id: D
				to: "tencentcloud_dnspod_domain_instance.\(DN)"
			}
		}
	}

	for type, records in #tencentcloud.dnspod.record {
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
	for sd in #tencentcloud.dnspod.sub_domains {
		let SD = "\(sd).\(D)"
		let SDN = regexp.ReplaceAllLiteral(R, SD, "_")

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
