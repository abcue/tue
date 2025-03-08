package tencentcloud

import "strings"

cvm: {
	#var: {
		name: string
		args: {
			vpc_name:          string
			subnet_name:       string
			availability_zone: string
		}
		instance: {
			req: {
				cpu:    *1 | int
				memory: *2 | int
			}
			args: {
				availability_zone: #var.args.availability_zone
				vpc_id:            "${local.rsc_id[\"\(strings.ToLower(#var.args.vpc_name)).vpc\"]}"
				subnet_id:         "${local.rsc_id[\"\(strings.ToLower(#var.args.subnet_name)).subnet\"]}"
				...
			}
		}
	}

	let N = #var.name

	data: tencentcloud_instance_types: (N): {
		cpu_core_count:   #var.instance.req.cpu
		memory_size:      #var.instance.req.memory
		exclude_sold_out: true
		filter: [{
			name: "instance-family"
			values: ["SA5"] // can be extended if needed
		}, {
			name: "zone"
			values: [#var.args.availability_zone]
		}]
	}

	resource: tencentcloud_instance: (N): #var.instance.args & {
		instance_name:                           N
		image_id:                                string | *"img-eb30mz89" // replace with tencentcloud_images resource
		instance_type:                           "${data.tencentcloud_instance_types.\(N).instance_types.0.instance_type}"
		instance_charge_type:                    *"PREPAID" | _
		instance_charge_type_prepaid_period:     *1 | _ // unit: month
		instance_charge_type_prepaid_renew_flag: *"NOTIFY_AND_AUTO_RENEW" | _
		system_disk_type:                        *"CLOUD_BSSD" | _
		system_disk_size:                        *50 | _ // unit: GB
		tags: {...}
		disable_api_termination: *true | false
		orderly_security_groups: ["${tencentcloud_security_group.\(N).id}"]
		allocate_public_ip: *false | true

		data_disks?: [{
			data_disk_type: string | *"CLOUD_BSSD"
			data_disk_size: int
		}, ...]
	}

	resource: tencentcloud_eip: (N): {
		count:                      1
		name:                       N
		internet_max_bandwidth_out: 10
		internet_charge_type:       "TRAFFIC_POSTPAID_BY_HOUR"
		type:                       "EIP"
		tags: {...}
	}

	resource: tencentcloud_eip_association: (N): {
		count:       1
		eip_id:      "${tencentcloud_eip.\(N)[0].id}"
		instance_id: "${tencentcloud_instance.\(N).id}"
	}

	resource: tencentcloud_security_group: (N): {
		name: "cvm-" + N
	}

	// https://cloud.tencent.com/document/product/457/9084
	resource: tencentcloud_security_group_rule_set: (N): {
		security_group_id: "${tencentcloud_security_group.\(N).id}"
		ingress: []
		egress: [{
			action:     "ACCEPT"
			cidr_block: "0.0.0.0/0"
			port:       "ALL"
			protocol:   "ALL"
		}]
	}

	output: (N): {
		value: {
			public_ip: "${tencentcloud_eip.\(N)[0].public_ip}"
		}
	}
}
