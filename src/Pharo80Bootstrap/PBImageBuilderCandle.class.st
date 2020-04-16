Class {
	#name : #PBImageBuilderCandle,
	#superclass : #PBImageBuilderSpur5032bitCustom,
	#category : #Pharo80Bootstrap
}

{ #category : #accessing }
PBImageBuilderCandle >> associationClass [
	
	^ self classNamed: (systemDefinition classWithRole: #Association) name
]

{ #category : #accessing }
PBImageBuilderCandle >> bindingOf: aName [

	([ self systemDefinition classNamed: aName ] on: Error do: [ nil ]) isNotNil
		ifTrue: [ ^ "(objectSpace classNamed: aName) mirror asClassMirror" 
			EPClassBinding new
				name: aName objectSpace: self;
				yourself ].
	(((self systemDefinition globalVariableNamed: aName) isNotNil) or: [(bootstrapEnvironment at: aName ifAbsent: [nil]) isNotNil])
		ifTrue: [ ^
			EPGlobalBinding new
				name: aName objectSpace: self;
				yourself ].
	self bootstrapEnvironment do: [:class | |rgClass|
		class isClassMirror ifTrue: [ 
			rgClass := class asClassMirror asRGClass.
			(rgClass classVarNames contains: [:cn | cn = aName])
				ifTrue: [|index|
					index := rgClass classVarNames indexOf: aName.
					^ EPClassVariableBinding new
						name: aName
						ownerName: rgClass theNonMetaClass name asSymbol
						objectSpace: self;
						yourself ]
			 ]
		].
			
	^ nil
]

{ #category : #running }
PBImageBuilderCandle >> createGlobalBindingFor: anEPGlobalBinding [ 

	^ bootstrappedBindingCache
		at: anEPGlobalBinding name
		ifAbsentPut: [ 
			| association |
			association := self newAssociation.
			association instanceVariableAtIndex: 1 put: (anEPGlobalBinding name asLiteralInObjectSpace: self objectSpace).
			association instanceVariableAtIndex: 2 put: ([ self valueForGlobal: anEPGlobalBinding name ] on: Exception do: [ self objectSpace nilObject ]).
			association ]
]

{ #category : #running }
PBImageBuilderCandle >> createInitialObjects [
	
	| smalltalk characterTable rsDictionary sDictionary |
	"We add the main globals  in the bootstrap environment before a system dictionary exists. These globals are needed to create a system dictionary, and will be used by the AST interpreter"
	self bootstrapEnvironment at: #Processor put: objectSpace nilObject.
	self bootstrapEnvironment at: #Smalltalk put: objectSpace nilObject.
	self bootstrapEnvironment at: #Undeclared put: (self bootstrapInterpreter evaluateCode: 'PCDictionary new').
	
	classLoader initializeClassPools.
	
	rsDictionary := self bootstrapInterpreter
		evaluateCode: 'aClassNamesCollection asDictionary'
		withTemps: { 
			'aClassNamesCollection' -> 
			(self objectSpace newArrayWithAll: 
				(self bootstrapEnvironment associations collect: [ :assoc | 
					self bootstrapInterpreter
						evaluateCode: 'key -> value'
						withTemps: { 'key' -> (assoc key asLiteralInObjectSpace: self objectSpace) .
										'value' -> assoc value }]))
		}.
	"sDictionary := EPRemoteDictionary on: sDictionary.
	bootstrapEnvironment associationsDo: [ :assoc |
		rsDictionary at: assoc key put: assoc value ].
	"
	
	smalltalk := self bootstrapInterpreter evaluateCode: 'Smalltalk := PCSmalltalk new instVarAt: 1 put: aSystemDictionary ; yourself.'
		withTemps: { 'aSystemDictionary' -> rsDictionary }.
	self bootstrapEnvironment at: #Smalltalk put: smalltalk.
	self bootstrapInterpreter evaluateCode: 'Smalltalk globals at: #Smalltalk put: Smalltalk'.
	espellBackend systemDictionary: (smalltalk instanceVariableAtIndex: 1).
	
	
	self bootstrapInterpreter evaluateCode: 'PCString initialize.'.
	
	self checkpoint: 'created_initial_objects'.

]

{ #category : #running }
PBImageBuilderCandle >> createVMStubs [

	| specialObjectsArray |
	super log: 'creating initial Objects needed by the VM'.
	self halt.
	self createNil.	
	self createFalse.
	self createTrue.

	self allocateFreeLists.	
	self allocateClassTable.
	
	specialObjectsArray := self objectSpace backend 
		createObjectWithFormat: Array format withSize: 60 classIndex: self arrayClassIndex.
	objectSpace specialObjectsArray: specialObjectsArray.
	objectSpace nilObject: objectSpace nilObject.
	objectSpace falseObject: objectSpace falseObject.
	objectSpace trueObject: objectSpace trueObject.
	
	objectSpace nilObject setClass: (self createStubForClassNamed: #PCUndefinedObject).
	objectSpace falseObject setClass: (self createStubForClassNamed: #PCFalse).
	objectSpace trueObject setClass: (self createStubForClassNamed: #PCTrue).
	
	objectSpace backend smallIntegerClass: (self createStubForClassNamed: #PCSmallInteger).
	objectSpace backend characterClass: (self createStubForClassNamed: #PCCharacter).
	objectSpace backend byteSymbolClass: (self createStubForClassNamed: #PCSymbol).
	objectSpace backend byteStringClass: (self createStubForClassNamed: #PCString).
	objectSpace backend byteArrayClass: (self createStubForClassNamed: #PCByteArray).
	objectSpace backend associationClass: (self createStubForClassNamed: #PCAssociation).
	objectSpace backend arrayClass: (self createStubForClassNamed: #PCArray).
	objectSpace backend symbolTableClass: objectSpace backend byteSymbolClass.
	objectSpace backend largeNegativeIntegerClass: (self createStubForClassNamed: #PCLargeNegativeInteger).
	objectSpace backend largePositiveIntegerClass: (self createStubForClassNamed: #PCLargePositiveInteger).
	objectSpace backend methodClass: (self createStubForClassNamed: #PCCompiledMethod).
	objectSpace backend floatClass: (self createStubForClassNamed: #PCFloat).
	objectSpace backend contextClass: (self createStubForClassNamed: #PCMethodContext).
	objectSpace backend processClass: (self createStubForClassNamed: #PCProcess).
	objectSpace backend blockClass: (self createStubForClassNamed: #PCBlock).
	"objectSpace backend fullBlockClass: (self createStubForClassNamed: #PCFullBlockClosure)."
	objectSpace backend messageClass: (self createStubForClassNamed: #PCMessage).
	
	"Point is required in the special objects array because it is used to instantiate point objects faster.
	If we do not put it here, the VM will crash.
	Lots of tests in kernel use it."
	objectSpace backend pointClass: (self createStubForClassNamed: #PCPoint).
	
	objectSpace backend processorAssociation: (self classNamed: #PCAssociation) mirror basicNew.
	objectSpace backend processorAssociation
		instanceVariableAtIndex: 2 put: (self createStubForClassNamed: #PCProcessorScheduler) basicNew.
	objectSpace backend specialSelectors: ((self classNamed: #PCArray) mirror basicNew: 64)
]

{ #category : #running }
PBImageBuilderCandle >> formatOfClass: aRFiClass [ 
	
	"A class format is composed by"
	"<5 bits inst spec><16 bits inst size>"
	| newHeap instSize newInstSpec |

	newHeap := objectSpace backend simulator objectMemory.
	((aRFiClass name = 'PCSmallInteger')
	 or: [(aRFiClass name = 'PCCharacter')]) ifTrue:
		[^ newHeap integerObjectOf: newHeap instSpecForImmediateClasses << 16].
	instSize := aRFiClass instSize.
	newInstSpec := self instSpecOfClass: aRFiClass.
	^newInstSpec << 16 + instSize
]

{ #category : #running }
PBImageBuilderCandle >> initialize [ 
	super initialize.
	bootstrappedBindingCache := Dictionary new
]

{ #category : #running }
PBImageBuilderCandle >> initializeImage [
	| process association |

	self flag: 'should migrate this method'.
	self checkpoint: 'image_initialization'.
	
	self initializeSpecialObjectArray.
	
	self bootstrapInterpreter
		evaluateCode:  '
	Processor := PCProcessorScheduler basicNew.
	Processor initProcessLists.'
		withTemps: #().

	
	
"	objectSpace backend processorAssociation: (self bootstrapInterpreter evaluateCode: 'Smalltalk globals associationAt: #Processor.').
	
	objectSpace processor: (objectSpace globalNamed: #Processor) asSchedulerMirror.
"	"objectSpace characterTable toInternalCharacterTable."
	association := self newAssociation.
	association instanceVariableAtIndex: 1 put: self objectSpace nilObject.
	association instanceVariableAtIndex: 2 put: (self bootstrapEnvironment at: #Processor).
	
	objectSpace backend processorAssociation: association .
	process := objectSpace createProcessWithPriority: 3 doing: 'PCSystem start' withTemps: #().
 	objectSpace installAsActiveProcess: process withProcessor: (self bootstrapEnvironment at: #Processor).
	
	self bootstrapInterpreter
		evaluateCode: 'PCSystem specialObjectsArray: newArray.'
		withTemps: { 'newArray' -> objectSpace backend specialObjectsArray }.
	
	self followForwardingPointers.

"	espellBackend simulator stackPages pages do: [ :page | espellBackend simulator stackPages freeStackPage: page ].
	espellBackend simulator freeUntracedStackPages.	
"
	PBStepFinishedSignal emit: 'image initialized'.
	self inform: 'Image Generated successfully'

]

{ #category : #running }
PBImageBuilderCandle >> initializeSpecialObjectArray [

"	objectSpace mustRebuildSpecialObjectsArray.
"	objectSpace specialObjectsArray: self newSpecialObjectsArray.

	self bootstrapInterpreter
		evaluateCode: 'PCSystem specialObjectsArray: newArray.'
		withTemps: { 'newArray' -> objectSpace backend specialObjectsArray }.
]

{ #category : #running }
PBImageBuilderCandle >> installMethod: method inBehavior: theClass [

	self objectSpace interpreter
		evaluateCode: 'theBehavior methodDict at: selector put: compiledMethod'
		withTemps:
			{'theBehavior' -> theClass.
			'selector' -> (method selector asLiteralInObjectSpace: objectSpace).
			'compiledMethod' -> method }
]

{ #category : #running }
PBImageBuilderCandle >> instantiateClassLoader [

	classLoader := PBSpurClassLoaderCandle new.
]

{ #category : #accessing }
PBImageBuilderCandle >> newAssociation [
	
	^ self associationClass mirror basicNew
]

{ #category : #running }
PBImageBuilderCandle >> setGlobal: aSymbol value: aValue [

	^ bootstrapEnvironment at: aSymbol put: aValue
]

{ #category : #running }
PBImageBuilderCandle >> valueForGlobal: aSymbol [

	^ bootstrapEnvironment at: aSymbol
]
