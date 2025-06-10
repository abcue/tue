package tencentcloud

cos: {
	#var: {
		name:    string
		product: *"cos" | _
	}

	let N = #var.name

	#tencentcloud: cos: bucket: args: _

	resource: tencentcloud_cos_bucket: (N): {
		#tencentcloud.cos.bucket.args
		bucket: N + "-${local.app_id}"
	}
}
