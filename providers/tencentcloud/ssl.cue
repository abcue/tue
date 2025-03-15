package tencentcloud

import "strings"

ssl: {
	#var: {
		product: *"ssl" | _
		ssl: [_]: {
			args: {...}
			vault: kv: {...}
		}
	}

	for n, ssl in #var.ssl {
		let N = strings.Replace(n, ".", "_", -1)
		resource: tencentcloud_ssl_certificate: (N): ssl.args & {
			name: n
			type: *"SVR" | "CA"
			cert: #"${chomp(data.vault_kv_secret_v2.\#(N).data["tls.crt"])}"#
			key:  #"${chomp(data.vault_kv_secret_v2.\#(N).data["tls.key"])}"#
		}
		data: vault_kv_secret_v2: (N): ssl.vault.kv
	}

	provider: vault: {}
}
