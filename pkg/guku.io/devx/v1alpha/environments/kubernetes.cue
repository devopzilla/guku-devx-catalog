package environments

import (
	"guku.io/devx/v1alpha"
	"guku.io/devx/v1alpha/transformers/compose"
)

Kubernetes: v1alpha.#Environment & {
	mainflows: [
		v1alpha.#Flow & {
			match: traits: Workload: null
			pipeline: [compose.#AddService]
		},
		v1alpha.#Flow & {
			match: traits: Exposable: null
			pipeline: [compose.#ExposeService]
		},
	]
}
