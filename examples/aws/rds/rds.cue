package rds

import (
	"registry.terraform.io/hashicorp/aws"
	"registry.terraform.io/hashicorp/random"
	"registry.terraform.io/carlpett/sops"
)

#var: {
	name:           _
	engine:         *"postgres" | _
	engine_version: *14 | _
	cloudwatch: {} | *{
		alarms: [string]: [string]: _
		alarms: {} | *{
			"FreeStorageSpace": "LessThanThreshold":           int | _local.tf_interp | *(0.15 * resource.aws_db_instance[#var.name].allocated_storage * 1Gi)
			"CPUUtilization": "GreaterThanOrEqualToThreshold": int | *60
			"DatabaseConnections": {
				"GreaterThanOrEqualToThreshold": int | *40
				"LessThanOrEqualToThreshold":    int | *-1
			}
			"WriteLatency": "GreaterThanOrEqualToThreshold": number | *0.2
			"ReadLatency": "GreaterThanOrEqualToThreshold":  number | *0.01
		}
		actions: [...string]
		dbs: [...string]
	}
}

provider: aws: region: _

resource: aws_db_instance?: [_]: {
	// Lock version upgrade to prevent uncontrolled changes.
	auto_minor_version_upgrade: false

	// Reasons for not enabling multi az by default
	// * Multi AZ will double the cost
	// * AZ failure is rare in AWS, lower than once per year.
	// * Restoring from snapshot may take up to 1 hour but it still reaches 99.99% SLA yearly
	// * It can be enabled for mission critical instances only.
	// multi_az:                   true

	// Extend retention period to prevent data corruption from application bugs and mal-operation.
	backup_retention_period: 14

	// Prevent instance from deletion by mistake
	deletion_protection: true

	performance_insights_enabled: true
}

_local: tf_interp: =~"\\${.*}"

resource: aws_db_parameter_group?: debezium: {
	name:   "debezium-" + family
	family: #var.engine + "\(#var.engine_version)"
	parameter: [{
		apply_method: "pending-reboot"
		name:         "rds.logical_replication"
		value:        "1"
	}]
}

terraform: {
	required_version:   ">= 1.0.0"
	required_providers: aws.#ProviderVersion & sops.#ProviderVersion
	backend: s3: {
		bucket:  *"terraform-backend" | _
		key:     string | *#var.name
		region:  "us-west-1"
		encrypt: true
	}
}

provider: aws.#Provider & sops.#Provider & random.#Provider & {
	aws: {
		region: _ | *"us-west-1"
		default_tags: [{tags: {
			terraform: "true"
			app:       #var.name
			owner:     #var.owner
		}}]
	}
	sops:   _
	random: _
}

variable: apply_immediately: {
	description: "Apply modification immediately"
	type:        "bool"
	default:     false
}

data: sops.#DataSources & {
	sops_file?: secrets: source_file: "secrets.enc.yaml"
}

if (data.sops_file.secrets != _|_) {
	locals: password: #"${data.sops_file.secrets.data["pgpass"]}"#
}

if (data.sops_file.secrets == _|_) {
	locals: password: "${random_password.this.result}"
	resource: random_password: this: {
		length:  32
		special: false
	}
}

// Declare default security groups for the instance
data: aws_security_group: _

resource: aws.#Resources & {
	aws_db_instance?: {
		"\(#var.name)": {
			identifier:            string | *#var.name
			engine:                "postgres"
			engine_version:        string | *"16"
			allocated_storage:     *200 | (int & <=16384) | _local.tf_interp
			max_allocated_storage: *(allocated_storage * 2) | int | _local.tf_interp
			storage_type:          *"gp3" | string
			storage_encrypted:     *true | _
			// https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html#gp3-storage
			if storage_type == "gp3" {
				iops: *12000 | _
			}

			// https://instances.vantage.sh/rds/?region=us-west-1&selected=db.t4g.large,db.m6i.large
			// T4G Large    db.t4g.large 8 GiB 0 GiB (EBS only) 2 vCPUs Up to 5 Gigabit $0.1710 hourly
			// M6I Large    db.m6i.large 8 GiB 0 GiB (EBS only) 2 vCPUs Up to 12.5 Gbps $0.2030 hourly
			instance_class: string | *"db.m6g.large"
			db_name:        string | *"postgres"
			username:       string | *"postgres"
			password:       "${local.password}"
			enabled_cloudwatch_logs_exports: [
				"postgresql",
				"upgrade",
			]
			backup_window:        string | *"01:00-03:00"
			maintenance_window:   string | *"sun:03:00-sun:05:00"
			apply_immediately:    "${var.apply_immediately}"
			ca_cert_identifier:   *"rds-ca-ecc384-g1" | string
			publicly_accessible:  true
			db_subnet_group_name: string | *"${data.aws_db_subnet_group.this.name}"
			vpc_security_group_ids: [...string] | *[
				for sg, _ in data.aws_security_group {
					"${data.aws_security_group.\(sg).id}"
				},
			]
			final_snapshot_identifier:  "\(#var.name)-final-snapshot"
			auto_minor_version_upgrade: *false | true
			if auto_minor_version_upgrade {
				lifecycle: ignore_changes: *["engine_version"] | _
			}
		}
	}
}

resource: aws_cloudwatch_metric_alarm?: {
	[_]: {
		namespace:                 "AWS/RDS"
		alarm_actions:             #var.cloudwatch.actions
		ok_actions:                #var.cloudwatch.actions
		insufficient_data_actions: #var.cloudwatch.actions
		period:                    600
		evaluation_periods:        int | *1
		statistic:                 "Average"
		dimensions: DBInstanceIdentifier: _

		metric_name:         string
		comparison_operator: string
		threshold:           number | #tf_interp

		alarm_name:        string | *"\(dimensions.DBInstanceIdentifier)_\(metric_name)_\(comparison_operator)"
		alarm_description: string | *"\(dimensions.DBInstanceIdentifier) \(metric_name) \(comparison_operator) \(threshold) within last \(period)s"
	}
	for metric, alarm in #var.cloudwatch.alarms {
		for comp, thres in alarm {
			for db in #var.cloudwatch.dbs {
				"\(db)_\(metric)_\(comp)": {
					metric_name:         metric
					comparison_operator: comp
					threshold:           thres
					dimensions: DBInstanceIdentifier: "${aws_db_instance.\(db).identifier}"
				}
			}
		}
	}
}

if resource.aws_db_instance != _|_ {
	output: connection: value: "host=${aws_db_instance.\(#var.name).address} port=${aws_db_instance.\(#var.name).port} user=${aws_db_instance.\(#var.name).username}"
}
