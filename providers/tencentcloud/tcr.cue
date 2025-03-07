package product

tcr: {
	#var: {
		name: string
		args: {
			vpc_name:          string
			subnet_name:       string
			availability_zone: string
		}
		tcr: {
			instance: {...}
			vpc_attachment: {...}
			namespace: [N=string]: {
				args: {
					// 长度2 - 30个字符，只能包含小写字母、数字及分隔符("."、"_"、"-")，且不能以分隔符开头、结尾或连续
					name: *N | _
					...
				}
				repository: [R=string]: {
					name: *R | _
					...
				}
			}
		}
	}

	let N = #var.name

	resource: tencentcloud_tcr_instance: (N): #var.tcr.instance & {
		name:                  N
		instance_type:         *"basic" | "standard" | "premium"
		open_public_operation: *false | true
	}

	resource: tencentcloud_tcr_vpc_attachment: (N): #var.tcr.vpc_attachment & {
		instance_id:              "${tencentcloud_tcr_instance.\(N).id}"
		vpc_id:                   "${local.vpc_id}"
		subnet_id:                "${local.subnet_id}"
		enable_public_domain_dns: true
		enable_vpc_domain_dns:    true
	}

	for n, ns in #var.tcr.namespace {
		let NS = "\(N)_\(n)"
		resource: tencentcloud_tcr_namespace: (NS): ns.arguments & {
			instance_id: "${tencentcloud_tcr_instance.\(N).id}"
		}

		for r, repo in ns.repository {
			let REPO = "\(NS)_\(r)"
			resource: tencentcloud_tcr_repository: (REPO): repo & {
				instance_id:    "${tencentcloud_tcr_instance.\(N).id}"
				namespace_name: "${tencentcloud_tcr_namespace.\(NS).name}"
			}
		}
	}
}
