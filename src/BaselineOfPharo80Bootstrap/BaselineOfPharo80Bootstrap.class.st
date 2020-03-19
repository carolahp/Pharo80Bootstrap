Class {
	#name : #BaselineOfPharo80Bootstrap,
	#superclass : #BaselineOf,
	#category : #BaselineOfPharo80Bootstrap
}

{ #category : #baselines }
BaselineOfPharo80Bootstrap >> baseline: spec [
	<baseline>
	
	spec for: #common do: [
		spec blessing: #baseline.
		spec baseline: 'Tonel' with: [ spec
			repository: 'github://pharo-vcs/tonel:v1.0.13' ].
		spec baseline: 'Hermes' with: [ spec
			repository: 'github://tesonep/hermes:v2.5.1';
  			loads: 'core' ].
		spec baseline: 'Espell' with: [ spec 
			repository: 'github://carolahp/espell:v2.2' ].
		spec
			 package: 'Pharo80Bootstrap'		
]
]
