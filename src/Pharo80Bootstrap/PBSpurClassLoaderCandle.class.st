Class {
	#name : #PBSpurClassLoaderCandle,
	#superclass : #PBSpurClassLoaderCustom,
	#category : #Pharo80Bootstrap
}

{ #category : #stubs }
PBSpurClassLoaderCandle >> classDefinitionFor: aClass [
	"Answer a String that defines the receiver."

	| type classInstallerName |

	type := self typeFor: aClass.
	
	classInstallerName := (self systemDefinition classWithRole: #ClassInstaller).
	
	^ '| newClass |
	newClass := (PCClassBuilder new
			superclass: {superClass};
			name: ''{name}'';
			instVarNames: {instanceVariablesString};
			classVariableNames: {classVariablesString};
			yourself)
		{type};
		build.		
	newClass'
	format: {
			'superClass' -> (aClass superclass ifNil: ['nil'] ifNotNil: [ :superclass | superclass name ]).
			'name' -> aClass name.
			'type' -> type.
			'instanceVariablesString' -> ('#(', (' ' join: aClass instVarNames), ')').
			'classVariablesString' -> aClass behaviorStrategy classPool keys printString } asDictionary.	.
	

]

{ #category : #binding }
PBSpurClassLoaderCandle >> classForClassMirror: anEPClassMirror [ 
	
	^ mirrorDefinitionMap at: anEPClassMirror ifAbsent: [ self systemDefinition classWithRole: #Class ]
]

{ #category : #stubs }
PBSpurClassLoaderCandle >> createBehaviorFromDefinition: aRFiDefinition [

	| newBehavior code |
	(self isFullyLoadedClassNamed: aRFiDefinition name) ifTrue: [ ^ self ].
	aRFiDefinition isBehavior ifTrue: [
		"We ensure a class with that name already exists"
		environment at: aRFiDefinition name ifAbsent: [ self createStubForClassNamed: aRFiDefinition name ]].
	
	newBehavior := self executeDefinitionFor: aRFiDefinition.
	code := 	'theBehavior methodDictionary: ({classMethodDictionary} new: capacity)' format: {'classMethodDictionary'-> (self systemDefinition classWithRole: #MethodDictionary) name } asDictionary.
		
	"Once the class is created we set a new method dictionary with a size that will make it grow less afterwards"

	builder bootstrapInterpreter 
		evaluateCode: code
		withTemps: { 
			'capacity' -> (aRFiDefinition methods size asLiteralInObjectSpace: builder objectSpace).
			'theBehavior' -> newBehavior }.
	
	aRFiDefinition isBehavior ifTrue: [ 
		self registerClass: newBehavior asClassMirror named: aRFiDefinition name fullyLoaded: true.
	] ifFalse: [
		self registerTrait: newBehavior asTraitMirror named: aRFiDefinition name fullyLoaded: true.
	].
	"we register the class by hand in the Smalltalk globals"
	builder bootstrapInterpreter 
		evaluateCode: 'Smalltalk globals at: aClassName put: aNewClass'
		withTemps: { 'aClassName' -> (aRFiDefinition name asSymbol asLiteralInObjectSpace: builder objectSpace) .
						 'aNewClass'  -> newBehavior }
]

{ #category : #binding }
PBSpurClassLoaderCandle >> createGlobalBindingFor: anEPGlobalBinding [ 
	^ builder createGlobalBindingFor: anEPGlobalBinding
]

{ #category : #stubs }
PBSpurClassLoaderCandle >> initializeClassPool: aClassName [

	| definition class classPool classVariableBindings |
	definition := self systemDefinition classNamed: aClassName.
	
	classVariableBindings := definition classVarNames collect: [ :each | | classVar |
		classVar := (self classNamed: self systemDefinition classClassVariable name) basicNew.
		classVar instanceVariableAtIndex: 1 put: (each asLiteralInObjectSpace: builder objectSpace) ].
	
	class := (environment at: aClassName) asClassMirror.
	classPool := builder bootstrapInterpreter
		evaluateCode: 'aClassVariableNamesCollection asDictionary'
		withTemps: { 
			'aClassVariableNamesCollection' -> (builder objectSpace newArrayWithAll: classVariableBindings)
		}.
	
	"Force the creation of the symbol using the object space class table." 
	self flag: #bug. "If we do not use basicSetClassName, we duplicate symbols"
	class basicSetClassName: (aClassName asLiteralInObjectSpace: builder objectSpace).
	class classPool: classPool.
	^ class
]

{ #category : #stubs }
PBSpurClassLoaderCandle >> isCompiledMethod: aClass [
	^ aClass = (self systemDefinition classWithRole: #CompiledMethod)
]

{ #category : #stubs }
PBSpurClassLoaderCandle >> metaclassClass [
	
	"Base case for recursion on class creation.
	Ok, so here we really go down and create the metaclass from nothing. We will use this metaclass to create all the others"
	| aClassMapping theNewMetaclass theNewMetaclassClass classFormat metaclassFormat metaclassIndex classIndex |
	
	environment at: #PCMetaclass ifPresent: [ :aClass | ^ aClass ].
	aClassMapping := self systemDefinition classNamed: #PCMetaclass.
	classFormat := self formatOfClass: aClassMapping.	
	metaclassFormat := self formatOfClass: aClassMapping metaclass.
	
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

	self registerClass: theNewMetaclass named: aClassMapping name.
	^ theNewMetaclass
]

{ #category : #stubs }
PBSpurClassLoaderCandle >> registerClass: aClassMirror named: aName fullyLoaded: aBoolean [

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

{ #category : #utils }
PBSpurClassLoaderCandle >> typeFor: aClass [

	aClass isImmediateClass
		ifTrue: [ ^ 'beImmediate' ].

	^ aClass isWeak
		ifTrue: [ 'beWeak' ]
		ifFalse: [ aClass isPointers
				ifTrue: [ aClass isVariable
						ifTrue: [ 'beVariable' ]
						ifFalse: [ 'yourself' ] ]
				ifFalse: [ (self isCompiledMethod: aClass)
						ifTrue: [ 'beCompiledMethod' ]
						ifFalse: [ aClass isWords
								ifTrue: [ 'beWords' ]
								ifFalse: [ 'beBytes' ] ] ] ]
]
