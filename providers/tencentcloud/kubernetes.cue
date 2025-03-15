package tencentcloud

import "regexp"

kubernetes: {
	let N = #var.name
	let TN = "tke-" + N

	#var: {
		name:    string
		product: *"kubernetes" | _
		args: {
			vpc_name:    string
			subnet_name: string
		}
		kubernetes: {
			cluster: {...}
			node_pool: [NAME=_]: {...}
		}
	}

	_local: cluster_id: "${tencentcloud_kubernetes_cluster.\(N).id}"

	resource: tencentcloud_kubernetes_cluster: (N): #var.kubernetes.cluster & {
		cluster_name:    N
		vpc_id:          "${local.vpc_id}"
		cluster_cidr:    *"172.18.0.0/16" | _
		cluster_version: *"1.30.0" | _
		// Default option in provider is `docker`, but it is not supported for cluster_version >=1.24
		// kubelet[161614]: E0226 14:34:51.595065  161614 run.go:74] "command failed" err="failed to run Kubelet: validate service connection: validate CRI v1 runtime API for endpoint \"unix:///run/cri-dockerd.sock\": rpc error: code = Unimplemented desc = unknown service runtime.v1.RuntimeService"
		container_runtime: "containerd"
		auth_options: {
			auto_create_discovery_anonymous_auth: true
			use_tke_default:                      true
		}
		// Managed by tencentcloud_kubernetes_cluster_endpoint
		lifecycle: ignore_changes: [
			"cluster_internet",
		]
	}

	resource: tencentcloud_kubernetes_native_node_pool?: (N)?: {
		name:       N
		type:       "Native"
		cluster_id: _local.cluster_id
		native: {
			instance_types: ["SA3.MEDIUM2"]
			instance_charge_type: "POSTPAID_BY_HOUR"
			key_ids: ["${tencentcloud_key_pair.\(TN).id}"]
			security_group_ids: ["${tencentcloud_security_group.\(TN).id}"]
			subnet_ids: ["${local.subnet_id}"]
			system_disk: {
				disk_type: "CLOUD_SSD"
				disk_size: 50
			}
		}
	}

	for n, np in #var.kubernetes.node_pool {
		resource: tencentcloud_kubernetes_node_pool: ("\(N)_\(n)"): np & {
			name:       n
			cluster_id: _local.cluster_id
			vpc_id:     "${local.vpc_id}"
			subnet_ids: ["${local.subnet_id}"]
			min_size: 0
			max_size: 3
			auto_scaling_config: {
				instance_type: *"SA3.MEDIUM2" | _
				key_ids: ["${tencentcloud_key_pair.\(TN).id}"]
				orderly_security_group_ids: ["${tencentcloud_security_group.\(TN).id}"]
			}
		}
	}

	resource: tencentcloud_key_pair: (TN): {
		// │ Error: key_name only support letters, numbers and "_": tke-avinf
		key_name: regexp.ReplaceAll("[^a-zA-Z0-9_]", TN, "_")
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
		cluster_id:                      _local.cluster_id
		cluster_internet:                true
		cluster_internet_security_group: "${tencentcloud_security_group.\(TNE).id}"
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
