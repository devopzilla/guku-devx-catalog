package traits

import (
	//"list"
	"struct"
	"guku.io/devx/v1alpha"
)

_#Container: {
	image: string @guku(required)
	command: [...string]
	args: [...string]
	env: [string]:    string | v1alpha.#Secret
	labels: [string]: string
	//mounts: [...{
	// volume:   _#VolumeSpec
	// path:     string
	// readOnly: bool | *true
	//}]
	resources: {
		requests?: {
			cpu?:    string
			memory?: string
		}
		limits?: {
			cpu?:    string
			memory?: string
		}
	}

	//restart: "on-fail" | "never" | *"always"
}

// a component that runs containers
#Workload: v1alpha.#Trait & {
	$metadata: traits: Workload: null

	containers: struct.MinFields(1) & {
		[string]: _#Container
	}
}

// a component that can be horizontally scaled
#Replicable: v1alpha.#Trait & {
	$metadata: traits: Replicable: null

	replicas: {
		min: uint | *1
		max: uint & >=min | *min
	}
}

_#Endpoint: {
	port: uint
	host: string
}

// a component that has endpoints that can be exposed
#Exposable: v1alpha.#Trait & {
	$metadata: traits: Exposable: null

	endpoints: struct.MinFields(1) & {
		[string]: _#Endpoint
	}
}

#Ingress: v1alpha.#Trait & {
	#Exposable

	$metadata: traits: Ingress: null
	ingress: struct.MinFields(1) & {
		[string]: {
			host:     string
			path:     string
			endpoint: _#Endpoint
		}
	}
}

// work around ambiguous disjunctions by disallowing fields
_#VolumeSpec: {
	local:       string
	secret?:     _|_
	ephemeral?:  _|_
	persistent?: _|_
} | {
	ephemeral:   string
	local?:      _|_
	secret?:     _|_
	persistent?: _|_
} | {
	persistent: string
	ephemeral?: _|_
	local?:     _|_
	secret?:    _|_
} | {
	secret:      v1alpha.#Secret
	ephemeral?:  _|_
	local?:      _|_
	persistent?: _|_
}

// a component that has a volume
#Volume: v1alpha.#Trait & {
	$metadata: traits: Volume: null

	volumes: [string]: _#VolumeSpec
}

// a postgres database
#Postgres: v1alpha.#Trait & {
	$metadata: traits: Postgres: null

	version:    string @guku(required)
	persistent: bool | *true
	port:       uint | *5432
	database:   string | *"default"

	host:     string
	username: string
	password: string
	url:      "postgresql://\(username):\(password)@\(host):\(port)/\(database)"
}

_#HelmCommon: {
	chart:     string @guku(required)
	url:       string @guku(required)
	version:   string @guku(required)
	values:    _ | *{}
	namespace: string
}

// a helm chart using helm repo
#Helm: v1alpha.#Trait & {
	$metadata: traits: Helm: null
	_#HelmCommon
}

// a helm chart using git
#HelmGit: v1alpha.#Trait & {
	$metadata: traits: HelmGit: null
	_#HelmCommon
}

// a helm chart using oci
#HelmOCI: v1alpha.#Trait & {
	$metadata: traits: HelmOCI: null
	_#HelmCommon
}

// an automation workflow
#Workflow: v1alpha.#Trait & {
	$metadata: traits: Workflow: null
	plan: _
}

// a component that has secrets
#Secret: v1alpha.#Trait & {
	$metadata: traits: Secret: null

	secrets: [string]: v1alpha.#Secret
}
