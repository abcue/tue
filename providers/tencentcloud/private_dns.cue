package product

import (
	"list"
	"regexp"
	"strings"
)

with: rsc_id: {
	#var: {
		args: {
			subnet_name: string
			vpc_name:    string
		}
		private_dns: {
			domain: string
			sub_domains: [...string]
		}
	}

	data: tencentcloud_private_dns_records: rsc_id: {
		zone_id: "${local.zone_id}"
	}

	data: tencentcloud_private_dns_private_zone_list: rsc_id: {
		filters: {
			name:   "Domain"
			values: "${[local.rsc_id_domain]}"
		}
	}

	data: tencentcloud_user_info: current: {}

	locals: {
		rsc_id:         "${{ for r in data.tencentcloud_private_dns_records.rsc_id.record_set : r.sub_domain => r.record_value }}"
		rsc_id_domain:  "id.\(#var.private_dns.domain)"
		rsc_id_zones:   "${{ for z in data.tencentcloud_private_dns_private_zone_list.rsc_id.private_zone_set : z.domain => z }}"
		rsc_id_zone_id: "${local.rsc_id_zones[local.rsc_id_domain].zone_id}"

		app_id:    "${data.tencentcloud_user_info.current.app_id}"
		vpc_id:    "${local.rsc_id[\"\(strings.ToLower(#var.args.vpc_name)).vpc\"]}"
		subnet_id: "${local.rsc_id[\"\(strings.ToLower(#var.args.subnet_name)).subnet\"]}"
	}

	// // Uncomment to debug
	// output: {
	// 	rsc_id: value: "${local.rsc_id}"
	// }
}

private_dns: {
	#var: {
		private_dns: {
			domain: *"" | string
			sub_domains: *[] | [...string]
			// a creates a record resolving to IPv4 addresses
			// a: [record]: =ipv4 | [...ipv4]
			a: *{} | {[string]: string | [...string]}
			cname: {
				[record_value=string]: [sub_domain=string]: _
			}
			srv: *{} | {[string]: string}
		}
	}

	resource?: tencentcloud_private_dns_zone?: [_]: {
		dns_forward_status: "DISABLED"
		vpc_set: {
			region:      #var.region
			uniq_vpc_id: "${local.vpc_id}"
		}
		cname_speedup_status: "DISABLED"
	}

	data?: tencentcloud_private_dns_private_zone_list?: this: {
		filters: {
			name: "Domain"
			values: [#var.domain]
		}
	}

	locals: domain_zone_id: "${{for zone in data.tencentcloud_private_dns_private_zone_list.this.private_zone_set : zone.domain => zone.zone_id}}"

	_local: {
		domain_zone_id: #"${local.domain_zone_id["\#(#var.private_dns.domain)"]}"#
		dns_replace:    "[^0-9a-zA-Z_\\-]"
	}

	for record, value in #var.private_dns.a for v in list.FlattenN([value], -1) {
		resource: tencentcloud_private_dns_record: (regexp.ReplaceAllLiteral(_local.dns_replace, record+v, "_")): {
			zone_id:      _local.domain_zone_id
			sub_domain:   record
			record_type:  "A"
			record_value: v
		}
	}

	for domain, records in #var.private_dns.cname for record, _ in records {
		resource: tencentcloud_private_dns_record: (regexp.ReplaceAllLiteral(_local.dns_replace, record, "_")): {
			zone_id:      _local.domain_zone_id
			sub_domain:   record
			record_type:  "CNAME"
			record_value: domain
		}
	}

	for record, value in #var.private_dns.srv for v in list.FlattenN([value], -1) {
		resource: tencentcloud_private_dns_record: (regexp.ReplaceAllLiteral(_local.dns_replace, v+record, "_")): {
			zone_id:      _local.domain_zone_id
			sub_domain:   v
			record_type:  "SRV"
			record_value: record
		}
	}

	for sd in #var.private_dns.sub_domains {
		resource: tencentcloud_private_dns_zone: {
			(sd): domain: "\(sd).\(#var.domain)"
		}
		resource: tencentcloud_private_dns_record: {
			(sd): {
				zone_id:      "${local.zone_id}"
				sub_domain:   "\(sd).\(#var.private_dns.domain).dns_zone"
				record_type:  "TXT"
				record_value: "${tencentcloud_private_dns_zone.\(sd).id}"
			}
		}
	}
}
