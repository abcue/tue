package tencentcloud

kubernetes: {
	let N = #var.name
	let TN = "tke-" + N

	#var: {
		name: string
		args: {
			vpc_name:    string
			subnet_name: string
		}
	}

	_local: cluster_id: "${tencentcloud_kubernetes_cluster.\(N).id}"

	resource: tencentcloud_kubernetes_cluster: (N): {
		cluster_name:     N
		vpc_id:           "${local.vpc_id}"
		cluster_cidr:     *"172.18.0.0/16" | _
		cluster_version:  *"1.30.0" | _
		cluster_internet: true
		// Default option in provider is `docker`, but it is not supported for cluster_version >=1.24
		// kubelet[161614]: E0226 14:34:51.595065  161614 run.go:74] "command failed" err="failed to run Kubelet: validate service connection: validate CRI v1 runtime API for endpoint \"unix:///run/cri-dockerd.sock\": rpc error: code = Unimplemented desc = unknown service runtime.v1.RuntimeService"
		container_runtime: "containerd"
		auth_options: {
			auto_create_discovery_anonymous_auth: true
			use_tke_default:                      true
		}
	}

	resource: tencentcloud_kubernetes_native_node_pool: (N): {
		name:       N
		type:       "Native"
		cluster_id: _local.cluster_id
		native: {
			instance_types: ["SA3.MEDIUM2"]
			instance_charge_type: "POSTPAID_BY_HOUR"
			key_ids: ["${tencentcloud_key_pair.\(N).id}"]
			security_group_ids: ["${tencentcloud_security_group.\(N).id}"]
			subnet_ids: ["${local.subnet_id}"]
			system_disk: {
				disk_type: "CLOUD_SSD"
				disk_size: 50
			}
		}
	}

	resource: tencentcloud_kubernetes_node_pool: (N): {
		name:       N
		cluster_id: _local.cluster_id
		vpc_id:     "${local.vpc_id}"
		subnet_ids: ["${local.subnet_id}"]
		min_size: 0
		max_size: 3
		auto_scaling_config: {
			instance_type: "SA3.MEDIUM2"
			key_ids: ["${tencentcloud_key_pair.\(N).id}"]
			orderly_security_group_ids: ["${tencentcloud_security_group.\(N).id}"]
		}
	}

	resource: tencentcloud_key_pair: (TN): {
		key_name: TN
	}

	data: tencentcloud_vpc_instances: vpc: {
		vpc_id: "${local.vpc_id}"
	}

	resource: tencentcloud_security_group: (TN): {
		name: TN
	}

	// https://cloud.tencent.com/document/product/457/9084
	resource: tencentcloud_security_group_rule_set: (TN): {
		security_group_id: "${tencentcloud_security_group.\(TN).id}"
		ingress: [{
			action:     "ACCEPT"
			cidr_block: "${data.tencentcloud_vpc_instances.vpc.instance_list[0].cidr_block}"
			port:       "ALL"
			protocol:   "ALL"
		}, {
			action:     "ACCEPT"
			cidr_block: "${tencentcloud_kubernetes_cluster.\(N).cluster_cidr}"
			port:       "ALL"
			protocol:   "ALL"
		}, {
			action:     "ACCEPT"
			cidr_block: "0.0.0.0/0"
			port:       "30000-32768"
			protocol:   "TCP"
		}, {
			action:     "ACCEPT"
			cidr_block: "0.0.0.0/0"
			port:       "30000-32768"
			protocol:   "UDP"
		}, {
			action:     "ACCEPT"
			cidr_block: "0.0.0.0/0"
			port:       "ALL"
			protocol:   "ICMP"
		}]
		egress: [{
			action:     "ACCEPT"
			cidr_block: "0.0.0.0/0"
			port:       "ALL"
			protocol:   "ALL"
		}]
	}

	let NE = N + "-extranet"
	let TNE = "tke-" + NE

	resource: tencentcloud_kubernetes_cluster_endpoint: (NE): {
		cluster_id:                      "${local.cluster_id}"
		cluster_internet:                true
		cluster_internet_security_group: "${tencentcloud_security_group.\(NE).id}"
	}

	resource: tencentcloud_security_group: (TNE): {
		name: TNE
	}

	// https://cloud.tencent.com/document/product/457/9084
	resource: tencentcloud_security_group_rule_set: (TNE): {
		security_group_id: "${tencentcloud_security_group.\(TNE).id}"
		ingress: []
		egress: [{
			action:     "ACCEPT"
			cidr_block: "0.0.0.0/0"
			port:       "ALL"
			protocol:   "ALL"
		}]
	}

	data: tencentcloud_kubernetes_cluster_authentication_options: (N): {
		cluster_id: _local.cluster_id
	}
}
