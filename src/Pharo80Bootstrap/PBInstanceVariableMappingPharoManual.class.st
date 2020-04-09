Class {
	#name : #PBInstanceVariableMappingPharoManual,
	#superclass : #PBInstanceVariableMappingPharoCustom,
	#category : #Pharo80Bootstrap
}

{ #category : #initialization }
PBInstanceVariableMappingPharoManual >> initializeIndexes [
	super initializeIndexes .
	metaclassThisClassIndex := self lookup: #thisClass in: #Metaclass.
]
