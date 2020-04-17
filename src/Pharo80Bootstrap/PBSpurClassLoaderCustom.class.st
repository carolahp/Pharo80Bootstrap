Class {
	#name : #PBSpurClassLoaderCustom,
	#superclass : #PBSpurClassLoader,
	#category : #Pharo80Bootstrap
}

{ #category : #'as yet unclassified' }
PBSpurClassLoaderCustom >> createClassStubForDefinition: aClassDefinition [
	
	| class metaclass |	
	metaclass := self metaclassClass basicNew asClassMirror.
	metaclass format: (self formatOfClass: aClassDefinition classSide).
	
	class := metaclass basicNew asClassMirror.
	class format: (self formatOfClass: aClassDefinition).
	
	metaclass instanceVariableAtIndex: builder objectSpace backend instanceVariableMapping metaclassThisClassIndex put: class. "soleInstance of the metaclass" 
	
	^ class
]

{ #category : #'as yet unclassified' }
PBSpurClassLoaderCustom >> initializeClassPools [

	shouldInitializeClassPool := true.
	(environment reject: [ :assoc | (assoc isClassMirror not) or: [assoc asClassMirror classNameFromAnyOrigin reverse beginsWith: 'ssalc '] ]) keysDo: [ :name |
		(self systemDefinition classNamed: name) isBehavior
			ifTrue: [ self initializeClassPool: name ] ].
]

{ #category : #'as yet unclassified' }
PBSpurClassLoaderCustom >> metaclassClass [
	
	"Base case for recursion on class creation.
	Ok, so here we really go down and create the metaclass from nothing. We will use this metaclass to create all the others"
	| aClassMapping theNewMetaclass theNewMetaclassClass classFormat metaclassFormat metaclassIndex classIndex |
	
	environment at: #Metaclass ifPresent: [ :aClass | ^ aClass ].

	aClassMapping := self systemDefinition classNamed: #Metaclass.
	classFormat := self formatOfClass: aClassMapping.	
	metaclassFormat := self formatOfClass: aClassMapping classSide.
	
	metaclassIndex := self newClassIndex.
	classIndex := self newClassIndex.
	
	theNewMetaclass := (builder objectSpace backend createObjectWithFormat: metaclassFormat withSize: 0 classIndex: classIndex) asClassMirror.
	theNewMetaclass format: classFormat.
	builder objectSpace backend objectMemory setHashBitsOf: theNewMetaclass target address to: metaclassIndex.
	builder objectSpace backend objectMemory classAtIndex: metaclassIndex put: theNewMetaclass target address.	
	
	
	theNewMetaclassClass := (builder objectSpace backend createObjectWithFormat: classFormat withSize: 0 classIndex: metaclassIndex) asClassMirror.
	theNewMetaclassClass format: metaclassFormat.
	builder objectSpace backend objectMemory setHashBitsOf: theNewMetaclassClass target address to: classIndex.
	builder objectSpace backend objectMemory classAtIndex: classIndex put: theNewMetaclassClass target address.
	
	theNewMetaclass setClass: theNewMetaclassClass.
	theNewMetaclassClass setClass: theNewMetaclass.
	
	self registerClass: theNewMetaclass named: aClassMapping name.
	^ theNewMetaclass
]

{ #category : #'as yet unclassified' }
PBSpurClassLoaderCustom >> registerClass: aClassMirror named: aName fullyLoaded: aBoolean [

	"If it existed before, we migrate its state"
	(environment includesKey: aName)
		ifTrue: [ 
			self migrateOldClass: (environment at: aName) to: aClassMirror ].

	"We register it and keep up to date our compact class index"
	
	environment at: aName put: aClassMirror.
	environment at: (aName,' class') asByteString put: aClassMirror basicClass.
	aClassMirror asClassMirror compactClassIndex = 0 ifFalse: [ 
		builder objectSpace backend compactClassAt: aClassMirror asClassMirror compactClassIndex put: aClassMirror ].
	
	"We create a mapping between the real classes and their definitions for later"
	self map: aClassMirror with: (self systemDefinition classNamed: aName).
	
	"We say the simulator that this class is a root, possible becomes can come into it. THIS IS ONLY VALID FOR SPUR SIMULATOR BOOTSTRAP. REFACTOR ME".
	self flag: #refactorMe.
	builder objectSpace backend addExtraRoot: aClassMirror.
	builder objectSpace backend addExtraRoot: aClassMirror classSide.
	
	"We reset the class map of the ast interpreter"
	fullyLoaded at: aName put: aBoolean
]
