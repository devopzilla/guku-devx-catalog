package aws

import (
	"list"
	"strings"
	"encoding/json"
	"strconv"
	"guku.io/devx/v1"
	"guku.io/devx/v1/traits"
)

_#TerraformResource: {
	$metadata: labels: {
		driver: "terraform"
		type:   ""
	}
	data: [string]:     _
	resource: [string]: _
}
_#ECSTaskDefinition: {
	family:       string
	network_mode: *"bridge" | "host" | "awsvpc" | "none"
	requires_compatibilities?: [..."EC2" | "FARGATE"]
	cpu?:    string
	memory?: string
	_container_definitions: [..._#ContainerDefinition]
	container_definitions: json.Marshal(_container_definitions)
}
_#ECSService: {
	name:            string
	cluster:         string
	task_definition: string
	desired_count:   uint | *1
	launch_type:     "EC2" | "FARGATE"
	network_configuration?: {
		security_groups: [...string]
		subnets: [...string]
	}
	load_balancer?: [...{
		target_group_arn: string
		container_name:   string
		container_port:   uint
	}]
}

// add a parameter store secret
#AddSSMSecretParameter: v1.#Transformer & {
	v1.#Component
	traits.#Secret
	$metadata: _
	secrets:   _
	$resources: terraform: _#TerraformResource & {
		resource: {
			aws_ssm_parameter: {
				for key, secret in secrets {
					"\(strings.ToLower($metadata.id))_\(strings.ToLower(key))": {
						name:  secret.key
						type:  "SecureString"
						value: "${random_password.\(strings.ToLower($metadata.id))_\(strings.ToLower(key)).result}"
					}
				}
			}
			random_password: {
				for key, _ in secrets {
					"\(strings.ToLower($metadata.id))_\(strings.ToLower(key))": {
						length:  32
						special: false
					}
				}
			}
		}
	}
}

// add an ECS service and task definition
#AddECSService: v1.#Transformer & {
	v1.#Component
	traits.#Workload
	$metadata:  _
	containers: _

	clusterName: string
	launchType:  "FARGATE" | "ECS"
	appName:     string | *$metadata.id
	$resources: terraform: _#TerraformResource & {
		data: aws_ecs_cluster: "\(clusterName)": cluster_name: clusterName
		resource: {
			aws_ecs_service: "\(appName)": _#ECSService & {
				name:            appName
				cluster:         "${data.aws_ecs_cluster.\(clusterName).id}"
				task_definition: "${aws_ecs_task_definition.\(appName).arn}"
				launch_type:     launchType
			}
			aws_ecs_task_definition: "\(appName)": _#ECSTaskDefinition & {
				family:       appName
				network_mode: "awsvpc"
				requires_compatibilities: [launchType]
				_cpu: list.Sum([
					0,
					for _, container in containers if container.resources.requests.cpu != _|_ {
						strconv.Atoi(strings.TrimSuffix(container.resources.requests.cpu, "m"))
					},
				])
				_memory: list.Sum([
						0,
						for _, container in containers if container.resources.requests.memory != _|_ {
						strconv.Atoi(strings.TrimSuffix(container.resources.requests.memory, "M"))
					},
				])
				if _cpu > 0 {
					cpu: "\(_cpu)"
				}
				if _memory > 0 {
					memory: "\(_memory)"
				}
				_container_definitions: [
					for k, container in containers {
						{
							essential: true
							name:      k
							image:     container.image
							command: [
								for v in container.command {
									v
								},
								for v in container.args {
									v
								},
							]

							environment: [
								for k, v in container.env {
									name:  k
									value: v
								},
							]

							healthCheck: {
								command: ["CMD-SHELL", "exit 0"]
							}

							if container.resources.requests.cpu != _|_ {
								cpu: strconv.Atoi(
									strings.TrimSuffix(container.resources.requests.cpu, "m"),
									)
							}
							if container.resources.limits.cpu != _|_ {
								ulimits: [{
									name:      "cpu"
									softLimit: strconv.Atoi(
											strings.TrimSuffix(container.resources.limits.cpu, "m"),
											)
									hardLimit: strconv.Atoi(
											strings.TrimSuffix(container.resources.limits.cpu, "m"),
											)
								}]
							}
							if container.resources.requests.memory != _|_ {
								memoryReservation: strconv.Atoi(
											strings.TrimSuffix(container.resources.requests.memory, "M"),
											)
							}
							if container.resources.limits.memory != _|_ {
								memory: strconv.Atoi(
									strings.TrimSuffix(container.resources.limits.memory, "M"),
									)
							}
						}
					},
				]
			}
		}
	}
}

// expose an ECS service through a load balancer
#ExposeECSService: v1.#Transformer & {
	v1.#Component
	traits.#Exposable
	$metadata:  _
	containers: _
	endpoints:  _

	vpcId: string
	subnets: [...string]
	lbTargetGroupName:   string
	lbSecurityGroupName: string
	lbHost:              string
	appName:             string | *$metadata.id
	endpoints: default: host: lbHost
	$resources: terraform: _#TerraformResource & {
		data: {
			aws_lb_target_group: "\(lbTargetGroupName)": name:  lbTargetGroupName
			aws_security_group: "\(lbSecurityGroupName)": name: lbSecurityGroupName
		}
		resource: {
			aws_security_group: "\(appName)": {
				name:   appName
				vpc_id: vpcId
				ingress: [
					for p in endpoints.default.ports {
						{
							protocol:  "tcp"
							from_port: p.port
							to_port:   p.port
							security_groups: [
								"${data.aws_security_group.\(lbSecurityGroupName).id}",
							]
							description:      null
							ipv6_cidr_blocks: null
							cidr_blocks:      null
							prefix_list_ids:  null
							self:             null
						}
					},
				]
				egress: [{
					protocol:  "-1"
					from_port: 0
					to_port:   0
					cidr_blocks: ["0.0.0.0/0"]
					security_groups:  null
					description:      null
					ipv6_cidr_blocks: null
					prefix_list_ids:  null
					self:             null
				}]
			}
			aws_ecs_service: "\(appName)": _#ECSService & {
				network_configuration: {
					security_groups: [
						"${aws_security_group.\(appName).id}",
					]
					"subnets": subnets
				}
				load_balancer: [
					for k, _ in containers {
						for p in endpoints.default.ports {
							{
								target_group_arn: "${data.aws_lb_target_group.\(lbTargetGroupName).arn}"
								container_name:   k
								container_port:   p.port
							}
						}
					},
				]
			}
			aws_ecs_task_definition: "\(appName)": _#ECSTaskDefinition & {
				network_mode: "awsvpc"
				_container_definitions: [
					...{
						portMappings: [
							for p in endpoints.default.ports {
								{
									containerPort: p.port
								}
							},
						]
					},
				]
			}
		}
	}
}

// Add ECS service replicas
#AddECSReplicas: v1.#Transformer & {
	v1.#Component
	traits.#Replicable
	$metadata: _
	replicas:  _
	appName:   string | *$metadata.id
	$resources: terraform: _#TerraformResource & {
		resource: aws_ecs_service: "\(appName)": _#ECSService & {
			desired_count: replicas.min
		}
	}
}
