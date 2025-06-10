package tencentcloud

tmp: {
	#var: {
		name:              string
		vpc_name:          string
		subnet_name:       string
		availability_zone: string
		domain:            string
		dns_zone:          *("tcop." + domain) | _
		tke_name:          string
		instance: {...}
	}

	let N = #var.name

	// TMP (Tencent Managed Service for Prometheus) Instance
	resource: tencentcloud_monitor_tmp_instance: (N): #var.instance & {
		instance_name:       N
		vpc_id:              #"${local.ids["\#(#var.vpc_name).vpc"]}"#
		subnet_id:           #"${local.ids["\#(#var.subnet_name).subnet"]}"#
		data_retention_time: *15 | _
		zone:                *#var.availability_zone | _
		tags: {
			created_by: "terraform"
		}
	}

	// Grafana Instance
	resource: tencentcloud_monitor_grafana_instance: (N): {
		instance_name: "\(N)-grafana"
		vpc_id:        #"${local.ids["\#(#var.vpc_name).vpc"]}"#
		subnet_ids: [#"${local.ids["\#(#var.subnet_name).subnet"]}"#]
		enable_internet: false
	}

	// Associate TMP and Grafana
	resource: tencentcloud_monitor_tmp_manage_grafana_attachment: (N): {
		instance_id: "${tencentcloud_monitor_tmp_instance.\(N).id}"
		grafana_id:  "${tencentcloud_monitor_grafana_instance.\(N).id}"
	}

	// Associate TMP and TKE Cluster
	if #var.tke_name != _|_ {
		data: tencentcloud_kubernetes_clusters: (#var.tke_name): {
			cluster_name: #var.tke_name
		}
		resource: tencentcloud_monitor_tmp_tke_cluster_agent: (N): {
			instance_id: "${tencentcloud_monitor_tmp_instance.\(N).id}"
			agents: {
				region:          #var.region
				cluster_type:    "tke"
				cluster_id:      "${data.tencentcloud_kubernetes_clusters.\(#var.tke_name).list[0].cluster_id}"
				enable_external: false
			}
		}
	}

	// DNS records
	resource: tencentcloud_private_dns_record: "\(N)-tmp": {
		zone_id:      "${local.ids[\"\(#var.dns_zone).dns_zone\"]}"
		record_type:  "A"
		record_value: "${tencentcloud_monitor_tmp_instance.\(N).ipv4_address}"
		sub_domain:   "\(N).prom"
		ttl:          300
	}
	resource: tencentcloud_private_dns_record: "\(N)-grafana": {
		zone_id:      "${local.ids[\"\(#var.dns_zone).dns_zone\"]}"
		record_type:  "A"
		record_value: "${split(\":\", tencentcloud_monitor_grafana_instance.\(N).internal_url)[0]}"
		sub_domain:   "\(N).grafana"
		ttl:          300
	}

	output: {
		tmp_id: {
			value: "${tencentcloud_monitor_tmp_instance.\(N).id}"
		}
		grafana_id: {
			value: "${tencentcloud_monitor_grafana_instance.\(N).id}"
		}
		tmp_host: {
			value: "http://\(N).prom.\(#var.dns_zone):9090"
		}
		grafana_host: {
			value: "http://\(N).grafana.\(#var.dns_zone):3000"
		}
	}
}
