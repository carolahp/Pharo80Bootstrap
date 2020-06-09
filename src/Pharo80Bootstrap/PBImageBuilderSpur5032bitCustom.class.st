Class {
	#name : #PBImageBuilderSpur5032bitCustom,
	#superclass : #PBImageBuilderSpur5032bit,
	#instVars : [
		'bootstrappedBindingCache',
		'debuggerInterpreter',
		'installOnlyMarkedMethods'
	],
	#category : #Pharo80Bootstrap
}

{ #category : #accessing }
PBImageBuilderSpur5032bitCustom >> bindingOf: aName [

	((self systemDefinition classNamed: aName) isNotNil)
		ifTrue: [ ^ EPClassBinding new
				name: aName objectSpace: self;
				yourself ].
	((self systemDefinition globalVariableNamed: aName) isNotNil)
		ifTrue: [ ^ EPGlobalBinding new
				name: aName objectSpace: self;
				yourself ].
	^ nil
]

{ #category : #accessing }
PBImageBuilderSpur5032bitCustom >> bootstrapInstallClasses: boolInstallClasses installMethods: boolInstallMethods installProcess: boolInstallProcess [
	self 
		initializeBootstrapEnvironment;
		createVMStubs;
		flushNewSpace;
		createInitialObjects.
		
	boolInstallClasses ifFalse: [ ^ self ].
	self 
		createClasses.
	
	boolInstallMethods ifFalse: [ ^ self ]. 
	self  
		installMethods;
		installExtensionMethods.
		
	boolInstallProcess ifFalse: [ ^self ].
	self 
		initializeImage
]

{ #category : #accessing }
PBImageBuilderSpur5032bitCustom >> debuggerInterpreter [
	^ debuggerInterpreter
]

{ #category : #accessing }
PBImageBuilderSpur5032bitCustom >> initializeBootstrapEnvironment [
	
	bootstrapEnvironment := Dictionary new.
	
	"We initialize the object space with a boot symbol table and character table.
	We will later replace them by real ones."
	objectSpace := EPObjectSpace new.
	objectSpace backend: espellBackend.
	objectSpace characterTable: (EPExternalCharacterTable new objectSpace: objectSpace; yourself).
	objectSpace symbolTable: (EPExternalSymbolTable new objectSpace: objectSpace; yourself).
	
	classLoader createJustStubs.
	classLoader environment: bootstrapEnvironment.
	classLoader builder: self.
	
	bootstrapInterpreter := EPASTEvaluator new.
	bootstrapInterpreter codeProvider: self.
	bootstrapInterpreter environment: self.
	bootstrapInterpreter objectSpace: objectSpace.
	 
	debuggerInterpreter := DASTEvaluator new.
	debuggerInterpreter codeProvider: self.
	debuggerInterpreter environment: self.
	debuggerInterpreter objectSpace: objectSpace.
	
	objectSpace interpreter: bootstrapInterpreter.
	objectSpace debuggerInterpreter: debuggerInterpreter
]

{ #category : #accessing }
PBImageBuilderSpur5032bitCustom >> installOnlyMarkedMethods [
	^ installOnlyMarkedMethods
]

{ #category : #accessing }
PBImageBuilderSpur5032bitCustom >> installOnlyMarkedMethods: aBoolean [ 
	installOnlyMarkedMethods := aBoolean
]

{ #category : #'accessing-image' }
PBImageBuilderSpur5032bitCustom >> spurImage [
	^ EP2SpurImage onFirstObject: espellBackend nilObject
]

{ #category : #'accessing-systemDefinition' }
PBImageBuilderSpur5032bitCustom >> systemDefinitionAt: aString [ 
	^ self systemDefinition classWithRole: aString
]

{ #category : #running }
PBImageBuilderSpur5032bitCustom >> writeImage [
	
	[[ espellBackend objectMemory flushNewSpace. ]
		on: Halt
		do: [:ex|
			(#(#fullGC #compactImage  #doScavenge:) includes: ex signalerContext sender selector)
				ifTrue: [ex resume]
				ifFalse: [ex pass]]] on: AssertionFailure do: [ :e |
				((e signalerContext sender method selector == #assert:)
					and: [ e signalerContext sender sender method selector = #mapStackPages ])
						ifTrue: [ e resume ]
						ifFalse: [ e pass ]].

	self freeForwarders.
	self compactImage.
	self reportSizes.

	self writeSnapshot: imageFileReference fullName ofTransformedImage: espellBackend simulator objectMemory headerFlags: 0 screenSize: 0.
	self inform: 'Image written in: ', imageFileReference fullName

]

{ #category : #'writing-image' }
PBImageBuilderSpur5032bitCustom >> writeImageIn: aFileReference [ 
	imageFileReference := aFileReference.	
	self writeImage
]
