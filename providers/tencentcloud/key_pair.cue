package tencentcloud

key_pair: {
	#var: {
		name: string
		key_pair: {
			...
		}
	}

	let N = #var.name

	resource: tencentcloud_key_pair: (N): #var.key_pair & {
		key_name:    N
		public_key?: string
	}
}
