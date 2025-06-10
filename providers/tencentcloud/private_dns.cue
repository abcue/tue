package tencentcloud

import (
	"list"
	"regexp"
	"strings"
)

with: rsc_id: {
	#tencentcloud: {
		private_dns: reqs: domain: string
		vpc: reqs: {
			subnet_name: string
			vpc_name:    string
		}
	}

	data: tencentcloud_private_dns_records: rsc_id: {
		zone_id: "${local.rsc_id_zone_id}"
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
		rsc_id_domain:  "id.\(#tencentcloud.private_dns.reqs.domain)"
		rsc_id_zones:   "${{ for z in data.tencentcloud_private_dns_private_zone_list.rsc_id.private_zone_set : z.domain => z }}"
		rsc_id_zone_id: "${local.rsc_id_zones[local.rsc_id_domain].zone_id}"

		app_id:    "${data.tencentcloud_user_info.current.app_id}"
		vpc_id:    *"${local.rsc_id[\"\(strings.ToLower(#tencentcloud.vpc.reqs.vpc_name)).vpc\"]}" | _
		subnet_id: *"${local.rsc_id[\"\(strings.ToLower(#tencentcloud.vpc.reqs.subnet_name)).subnet\"]}" | _
	}
}

private_dns: {
	#var: name: string

	let N = #var.name

	#tencentcloud: {
		provider: args: region: string
		private_dns: reqs: {
			domain: *N | string
			sub_domains: *[] | [...string]
			records: [type=string]: [sub_domain=string]: string | [...string]
			migrate?: _
		}
	}

	let D = #tencentcloud.private_dns.reqs.domain

	resource?: tencentcloud_private_dns_zone: [_]: {
		dns_forward_status: "DISABLED"
		vpc_set: {
			region:      #tencentcloud.provider.args.region
			uniq_vpc_id: "${local.vpc_id}"
		}
		cname_speedup_status: "DISABLED"
	}

	let RN = strings.Replace(N, ".", "_", -1)
	resource?: tencentcloud_private_dns_zone?: (RN)?: {
		domain: N
	}

	if resource.tencentcloud_private_dns_zone[RN] == _|_ {
		data: tencentcloud_private_dns_private_zone_list: this: {
			filters: {
				name: "Domain"
				values: [N]
			}
		}
		locals: domain_zone_id: #"${lookup({for zone in data.tencentcloud_private_dns_private_zone_list.this.private_zone_set : zone.domain => zone.zone_id}, "\#(N)", null)}"#
	}

	if resource.tencentcloud_private_dns_zone[RN] != _|_ {
		locals: domain_zone_id: "${tencentcloud_private_dns_zone.\(RN).id}"
	}

	for sd in #tencentcloud.private_dns.reqs.sub_domains {
		resource: tencentcloud_private_dns_zone: {
			(sd): domain: "\(sd).\(D)"
		}
		resource: tencentcloud_private_dns_record: {
			(sd): {
				zone_id:      "${local.rsc_id_zone_id}"
				sub_domain:   "\(sd).\(D).dns_zone"
				record_type:  "TXT"
				record_value: "${tencentcloud_private_dns_zone.\(sd).id}"
			}
		}
	}

	for type, subdomains in #tencentcloud.private_dns.reqs.records for sd, value in subdomains for v in list.FlattenN([value], -1) {
		let RN = regexp.ReplaceAll("[^0-9a-zA-Z_\\-]", strings.Join([type, sd, v], "_"), "_")
		resource: tencentcloud_private_dns_record: (RN): {
			zone_id:      "${local.domain_zone_id}"
			sub_domain:   sd
			record_type:  strings.ToUpper(type)
			record_value: v
		}
	}

	if #tencentcloud.private_dns.reqs.migrate != _|_ {
		output: migrate: value: strings.Join([
			for sd, value in #tencentcloud.private_dns.reqs.records.cname for v in list.FlattenN([value], -1) {
				let OLD = regexp.ReplaceAll("[^0-9a-zA-Z_\\-]", sd, "_")
				let NEW = regexp.ReplaceAll("[^0-9a-zA-Z_\\-]", strings.Join(["cname", sd, v], "_"), "_")
				"terraform state mv tencentcloud_private_dns_record.\(OLD) tencentcloud_private_dns_record.\(NEW)"
			},
			for sd, value in #tencentcloud.private_dns.reqs.records.a for v in list.FlattenN([value], -1) {
				let OLD = regexp.ReplaceAll("[^0-9a-zA-Z_\\-]", sd+v, "_")
				let NEW = regexp.ReplaceAll("[^0-9a-zA-Z_\\-]", strings.Join(["a", sd, v], "_"), "_")
				"terraform state mv tencentcloud_private_dns_record.\(OLD) tencentcloud_private_dns_record.\(NEW)"
			},
		], "\n")
	}
}
