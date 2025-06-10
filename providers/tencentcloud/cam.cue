package tencentcloud

import "encoding/json"

// replace `cam` with the actual product name
cam: {
	#var: {
		name:    string
		product: *"cam" | _
	}

	let N = #var.name

	#tencentcloud: cam: {
		group: args: _
		users: *{(N): _} | _
		reqs: {
			cos: [bucket=_]: _
			api_key: *false | true
		}
		policies: *[] | [string]
	}

	resource: tencentcloud_cam_group: (N): {
		#tencentcloud.cam.group.args
		name: N
	}

	for n, u in #tencentcloud.cam.users {
		resource: tencentcloud_cam_user: (n): {
			name: n
		}
	}

	resource: tencentcloud_cam_group_membership: (N): {
		group_id: "${tencentcloud_cam_group.\(N).id}"
		user_names: [for n, _ in #tencentcloud.cam.users {"${tencentcloud_cam_user.\(n).id}"}]
	}

	if len(#tencentcloud.cam.reqs.cos) > 0 {
		resource: tencentcloud_cam_policy: (N): {
			name: N
			document: json.Marshal({
				version: "2.0"
				statement: [{
					effect: "allow"
					action: ["cos:*"]
					resource: [for b, _ in #tencentcloud.cam.reqs.cos {
						"qcs::cos::uid/${data.tencentcloud_user_info.current.app_id}:\(b)-${data.tencentcloud_user_info.current.app_id}/*"
					}]
				}]
			})
		}
		resource: tencentcloud_cam_group_policy_attachment: (N): {
			group_id:  "${tencentcloud_cam_group.\(N).id}"
			policy_id: "${tencentcloud_cam_policy.\(N).id}"
		}
	}

	for p in #tencentcloud.cam.policies {
		data: tencentcloud_cam_policies: (p): {
			name: p
		}
		resource: tencentcloud_cam_group_policy_attachment: (p): {
			group_id:  "${tencentcloud_cam_group.\(N).id}"
			policy_id: "${data.tencentcloud_cam_policies.\(p).policy_list.0.policy_id}"
		}

	}

	if #tencentcloud.cam.reqs.api_key {
		for n, _ in #tencentcloud.cam.users {
			output: "tencentcloud_cam_user_api_key_\(n)": {
				value: {
					"${tencentcloud_cam_user.\(n).id}": {
						secret_id:  "${tencentcloud_cam_user.\(n).secret_id}"
						secret_key: "${tencentcloud_cam_user.\(n).secret_key}"
					}
				}
				sensitive: true
			}
		}
	}
}
