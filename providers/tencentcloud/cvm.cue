package tencentcloud

import "strings"

cvm: {
	#var: name: string

	#tencentcloud: {
		vpc: reqs: {
			vpc_name:          string
			subnet_name:       string
			availability_zone: string
		}
		instance: {
			reqs: {
				cpu:   *1 | int
				mem:   *2 | int
				disk?: *10 | int
				eip:   *false | true
				key_pairs: [group=_]: [...string]
				set_password: *false | true
			}
			args: {
				availability_zone: vpc.reqs.availability_zone
				vpc_id:            "${local.rsc_id[\"\(strings.ToLower(vpc.reqs.vpc_name)).vpc\"]}"
				subnet_id:         "${local.rsc_id[\"\(strings.ToLower(vpc.reqs.subnet_name)).subnet\"]}"
				...
			}
		}
		security_group: reqs: ingress: [port=_]: {
			args: _
			reqs: ipm: [...string]
		}
		private_dns: reqs: domain: string
	}

	let N = #var.name

	// │     │ data.tencentcloud_instance_types.pxe.instance_types is empty list of object
	data: tencentcloud_instance_types?: (N)?: {
		cpu_core_count:   #tencentcloud.instance.reqs.cpu
		memory_size:      #tencentcloud.instance.reqs.mem
		exclude_sold_out: true
		filter: [{
			name: "instance-family"
			values: ["SA5", "S8", "SA4", "S6", "SA3"] // can be extended if needed
		}, {
			name: "zone"
			values: [#tencentcloud.vpc.reqs.availability_zone]
		}]
	}

	resource: tencentcloud_instance: (N): #tencentcloud.instance.args & {
		instance_name: N
		image_id:      string | *"img-eb30mz89" // replace with tencentcloud_images resource

		instance_type: *"SA5.MEDIUM2" | _
		if data.tencentcloud_instance_types[N] != _|_ {
			instance_type: "${data.tencentcloud_instance_types.\(N).instance_types.0.instance_type}"
		}

		instance_charge_type:                    *"PREPAID" | _
		instance_charge_type_prepaid_period:     *1 | _ // unit: month
		instance_charge_type_prepaid_renew_flag: *"NOTIFY_AND_AUTO_RENEW" | _
		system_disk_type:                        *"CLOUD_BSSD" | _
		system_disk_size:                        *50 | _ // unit: GB
		tags: {...}
		disable_api_termination: *true | false
		orderly_security_groups: ["${tencentcloud_security_group.\(CN).id}"]
		allocate_public_ip: *false | true

		if len(#tencentcloud.instance.reqs.key_pairs) > 0 {
			key_ids: [for group, keys in #tencentcloud.instance.reqs.key_pairs for key in keys {
				"${local.rsc_id[\"\(key)_\(group).key_pair\"]}"
			}]
		}

		if #tencentcloud.instance.reqs.disk != _|_ {
			data_disks?: [{
				data_disk_type: string | *"CLOUD_BSSD"
				data_disk_size: #tencentcloud.instance.reqs.disk
			}, ...]
		}
	}

	let CN = "cvm_\(N)"

	if #tencentcloud.instance.reqs.set_password {
		resource: random_password: (CN): {
			length:  16
			special: true
		}
		resource: tencentcloud_instance: (N): password: "${random_password.\(CN).result}"
	}

	if #tencentcloud.instance.reqs.eip {
		resource: tencentcloud_eip: (CN): {
			count:                      1
			name:                       CN
			internet_max_bandwidth_out: 10
			internet_charge_type:       "TRAFFIC_POSTPAID_BY_HOUR"
			type:                       "EIP"
			tags: {...}
		}

		resource: tencentcloud_eip_association: (CN): {
			count:       1
			eip_id:      "${tencentcloud_eip.\(CN)[0].id}"
			instance_id: "${tencentcloud_instance.\(N).id}"
		}
	}

	resource: tencentcloud_security_group: (CN): {
		name: CN
	}

	// https://cloud.tencent.com/document/product/457/9084
	resource: tencentcloud_security_group_rule_set: (CN): {
		security_group_id: "${tencentcloud_security_group.\(CN).id}"
		ingress: [
			for port, igr in #tencentcloud.security_group.reqs.ingress for _, ipm in igr.reqs.ipm {
				igr.args
				action:              *"ACCEPT" | _
				protocol:            *"TCP" | _
				"port":              *port | _
				address_template_id: *#"${local.rsc_id["\#(ipm).ipm"]}"# | _
			},
		]
		egress: [{
			action:     "ACCEPT"
			cidr_block: "0.0.0.0/0"
			port:       "ALL"
			protocol:   "ALL"
		}]
	}

	let CD = "cvm.\(#tencentcloud.private_dns.domain)"
	let CZ = #"${local.rsc_id["\#(CD).dns_zone"]}"#

	resource: tencentcloud_private_dns_record: "\(CN)_A": {
		zone_id:      CZ
		sub_domain:   "${tencentcloud_instance.\(N).id}"
		record_value: "${tencentcloud_instance.\(N).private_ip}"
		record_type:  "A"
		ttl:          300
	}

	resource: tencentcloud_private_dns_record: "\(CN)_CNAME": {
		zone_id:      CZ
		sub_domain:   N
		record_value: "${tencentcloud_instance.\(N).id}.\(CD)"
		record_type:  "CNAME"
		ttl:          300
	}
}
