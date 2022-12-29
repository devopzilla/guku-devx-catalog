package compose

import (
	"strings"
	"guku.io/devx/v1alpha"
	transformers "guku.io/devx/v1alpha/transformers/compose"
)

#AddService: v1alpha.#Flow & {
	match: traits: Workload: null
	pipeline: [transformers.#AddService]
}

#ExposeService: v1alpha.#Flow & {
	match: traits: Exposable: null
	pipeline: [transformers.#ExposeService]
}

#ExposePort: v1alpha.#Flow & {
	match: traits: Workload:              null
	match: traits: Exposable:             null
	match: labels: "compose/expose-port": string
	pipeline: [
		v1alpha.#Transformer & {
			$metadata: _
			$resources: compose: services: "\($metadata.id)": {
				ports: [
					for port in strings.Split($metadata.labels["compose/expose-port"], ",") {
						port
					},
				]
			}
		},
	]
}

#AddTraefikLabels: v1alpha.#Flow & {
	match: traits: Ingress:  null
	match: traits: Workload: null

	pipeline: [
		v1alpha.#Transformer & {
			$metadata: _

			ingress: [ID=string]: {
				host: "\(ID).\($metadata.id).traefik.localhost"
			}

			containers: [string]: {
				labels: {
					for id, ing in ingress {
						"traefik.http.routers.\($metadata.id)-\(id).rule":                      "Host(`\(ing.host)`)"
						"traefik.http.services.\($metadata.id)-\(id).loadbalancer.server.port": "\(ing.endpoint.port)"
					}
				}

			}
		},
	]
}
