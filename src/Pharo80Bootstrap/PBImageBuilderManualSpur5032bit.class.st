Class {
	#name : #PBImageBuilderManualSpur5032bit,
	#superclass : #PBImageBuilderSpur5032bitCustom,
	#category : #Pharo80Bootstrap
}

{ #category : #initialization }
PBImageBuilderManualSpur5032bit >> associationClass [
	
	^ self classNamed: (systemDefinition classAssociation) name
]

{ #category : #running }
PBImageBuilderManualSpur5032bit >> createGlobalBindingFor: anEPGlobalBinding [ 

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
PBImageBuilderManualSpur5032bit >> createInitialObjects [
	
	| characterTable |
	"We add the main globals  in the bootstrap environment before a system dictionary exists. These globals are needed to create a system dictionary, and will be used by the AST interpreter"
	PBStepFinishedSignal emit: 'initializing globals'.
	self bootstrapEnvironment at: #Smalltalk put: objectSpace nilObject.
	self bootstrapEnvironment at: #Undeclared put: objectSpace nilObject.
	
	"We initialize the hash table sizes by hand.
	The AST interpreter is too slow to interpret HashTableSizes>>#initialize"
	PBSubStepFinishedSignal emit: 'initializing hash table sizes'.
	
	(self classNamed: #HashTableSizes) mirror
		instanceVariableAtIndex: (self classInstanceVariableIndexAt: 1)
		put: (objectSpace newArrayWithAll: (HashTableSizes sizes collect: [:each | objectSpace backend smallIntegerMirrorOn: each ])).
	
	PBSubStepFinishedSignal emit: 'preparing class builder'.
	self bootstrapInterpreter evaluateCode: 'DangerousClassNotifier disable'.

	self bootstrapInterpreter evaluateCode: 'Undeclared := Dictionary new.'.
	self bootstrapInterpreter evaluateCode: 'Smalltalk := SmalltalkImage basicNew.'.
	
	self bootstrapInterpreter evaluateCode: 'Smalltalk instVarAt: 1 put: (SystemDictionary withOrganizer: SystemOrganizer new).'.
	self bootstrapInterpreter evaluateCode: 'Smalltalk globals at: #Smalltalk put: Smalltalk.'.
	self bootstrapInterpreter evaluateCode: 'Smalltalk globals at: #Undeclared put: Undeclared.'.

	"Initialize the globals of the system. Careful: The AST interpreter will not know about these if we do not put them in the bootstrapEnvironment."	
	self bootstrapInterpreter evaluateCode: 'Smalltalk globals at: #Processor put: nil.'.
	self bootstrapInterpreter evaluateCode: 'Smalltalk globals at: #Transcript put: nil.'.
	self bootstrapInterpreter evaluateCode: 'Smalltalk globals at: #SystemOrganisation put: nil.'.
	self bootstrapInterpreter evaluateCode: 'Smalltalk globals at: #SourceFiles put: nil.'.

	
	PBSubStepFinishedSignal emit: 'class loader now creates class pools'.
	classLoader initializeClassPools.

	PBSubStepFinishedSignal emit: 'Initializing StartUp list'.
	self bootstrapInterpreter evaluateCode: 'SmalltalkImage initialize.'.
	
	PBSubStepFinishedSignal emit: 'Initializing Character Table'.
	self bootstrapInterpreter evaluateCode: 'Character initialize.'.
	characterTable := (EP2InternalCharacterTable new objectSpace: objectSpace).
	objectSpace backend characterTable: ((self classNamed: #Character) classPool at: #CharacterTable).
	objectSpace characterTable: characterTable.
	
	PBSubStepFinishedSignal emit: 'Initializing String AsciiTable'.
	self bootstrapInterpreter evaluateCode: 'String classPool at: #AsciiOrder put: ((0 to: 255) as: ByteArray).'.
	
	PBSubStepFinishedSignal emit: 'Initializing SmallInteger constants'.
	self bootstrapInterpreter evaluateCode: 'SmallInteger instVarAt: ' , (self classInstanceVariableIndexAt: 1) asString ,' put: -16r40000000.' "minVal".
	self bootstrapInterpreter evaluateCode: 'SmallInteger instVarAt: ' , (self classInstanceVariableIndexAt: 2) asString ,' put: 16r3FFFFFFF.' "maxVal".

	PBSubStepFinishedSignal emit: 'Initializing Date and Time constants'.
	self bootstrapInterpreter evaluateCode: 'DateAndTime initialize.'.
	self bootstrapInterpreter evaluateCode: 'ChronologyConstants initialize.'.
	
	PBSubStepFinishedSignal emit: 'Initializing CompiledMethod constants'.
	self bootstrapInterpreter evaluateCode: 'CompiledMethod initialize.'.
	
	PBSubStepFinishedSignal emit: 'Initializing object dependent fields'.
	self bootstrapInterpreter evaluateCode: 'Object initialize.'.
	
	PBSubStepFinishedSignal emit: 'Installing symbol table'.
	self bootstrapInterpreter evaluateCode: 'Symbol initialize.
	Symbol classPool at: #SymbolTable put: (WeakSet withAll: ByteSymbol allInstances)'.
	objectSpace symbolTable: (EP2InternalSymbolTable new objectSpace: objectSpace).

	
	PBSubStepFinishedSignal emit: 'Bootstrapping class layouts'.
	bootstrapInterpreter evaluateCode:
		('| superLayout |
		superLayout := EmptyLayout instance.
		Class
			instVarAt: 4
			put: (FixedLayout
					extending: superLayout 
					scope: (superLayout slotScope extend: #({1}))
					host: Class).
		
		SmallInteger
			instVarAt: 4
			put: (ImmediateLayout new).' format: {self espellBackend instanceVariableMapping listOfClassSlots}).
			
	PBStepFinishedSignal emit: 'Class builder ready to create classes'.
	classLoader useClassBuilder.
	
	self checkpoint: 'created_initial_objects'.
]

{ #category : #initialization }
PBImageBuilderManualSpur5032bit >> initialize [ 
	super initialize.
	bootstrappedBindingCache := Dictionary new
]

{ #category : #initialization }
PBImageBuilderManualSpur5032bit >> initializeImage [
	| process |

	self checkpoint: 'image_initialization'.
	
	self initializeSpecialObjectArray.
	
	self bootstrapInterpreter evaluateCode: '
	Smalltalk at: #Processor put: (ProcessorScheduler basicNew).
	(Smalltalk at: #Processor) instVarAt: 1 put: ((1 to: 80) collect: [ :i | ProcessList new ])'.

	"Initialize the processor association for the special objects array.
	Enchancement possible: This should be automatically managed by the createVMStubs method"
	objectSpace backend processorAssociation: (self bootstrapInterpreter evaluateCode: 'Smalltalk globals associationAt: #Processor.').
	
	process := objectSpace
		createProcessWithPriority: 40 
		doing: ('PharoBootstrapInitialization 
			initializeImageOfType: ''Pharo'' 
			major: {major} 
			minor: {minor} 
			patch: {patch}
			suffix: ''{suffix}'' 
			build: {build} 
			commitHash: ''{hash}''.' 
		format: {
			'major' -> versionInfo major. "7"
			'minor' -> versionInfo minor. "0"
			'patch' -> versionInfo patch. "0"
			'suffix' -> versionInfo suffix. "'alpha'"
			'build' -> versionInfo buildNumber. "-1"
			'hash' -> versionInfo commitHash. " d40cba880"
	} asDictionary).
 	objectSpace installAsActiveProcess: process.
	
	self followForwardingPointers.

"	espellBackend simulator stackPages pages do: [ :page | espellBackend simulator stackPages freeStackPage: page ].
	espellBackend simulator freeUntracedStackPages."

	PBStepFinishedSignal emit: 'image initialized'.
	self inform: 'Image Generated Successfully'.
	

]

{ #category : #accessing }
PBImageBuilderManualSpur5032bit >> instantiateClassLoader [

	classLoader := PBSpurClassLoaderManual new.
]

{ #category : #initialization }
PBImageBuilderManualSpur5032bit >> newAssociation [
	
	^ self associationClass mirror basicNew
]

{ #category : #accessing }
PBImageBuilderManualSpur5032bit >> setGlobal: aString value: anEPMirror [ 
	^ bootstrapEnvironment at: aString put: anEPMirror 
]

{ #category : #initialization }
PBImageBuilderManualSpur5032bit >> valueForGlobal: aSymbol [

	^ bootstrapEnvironment at: aSymbol
]
