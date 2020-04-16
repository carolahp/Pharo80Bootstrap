Class {
	#name : #PBBootstrapCustom,
	#superclass : #PBBootstrap,
	#instVars : [
		'builder',
		'pbRepository',
		'installOnlyMarkedMethods'
	],
	#category : #Pharo80Bootstrap
}

{ #category : #accessing }
PBBootstrapCustom >> builder [
	^ builder
]

{ #category : #accessing }
PBBootstrapCustom >> builderClass [

	self subclassResponsibility 
]

{ #category : #accessing }
PBBootstrapCustom >> createImage [
	self initializeBuilder.
	builder bootstrap
]

{ #category : #accessing }
PBBootstrapCustom >> environment [
	^ self pbRepository ringEnvironment
]

{ #category : #accessing }
PBBootstrapCustom >> initializeBuilder [
	builder := self builderClass new.
	builder versionInfo: versionInfo.
	builder imageFileReference: imageReference.
	builder systemDefinition: self environment.
	builder espellBackend instanceVariableMapping: (self instanceVariableMappingClass onEnvironment: self environment ).
]

{ #category : #bootstrapping }
PBBootstrapCustom >> installClasses [ 
	builder createClasses
		
]

{ #category : #bootstrapping }
PBBootstrapCustom >> installMethods [
	builder 
		installOnlyMarkedMethods: self installOnlyMarkedMethods;
		installMethods;
		installExtensionMethods
		
]

{ #category : #accessing }
PBBootstrapCustom >> installOnlyMarkedMethods [
	^ installOnlyMarkedMethods ifNil: [ installOnlyMarkedMethods := false ]
]

{ #category : #accessing }
PBBootstrapCustom >> installOnlyMarkedMethods: aBoolean [ 
	installOnlyMarkedMethods := aBoolean
]

{ #category : #bootstrapping }
PBBootstrapCustom >> installProcess [
	builder 
		initializeImage
]

{ #category : #bootstrapping }
PBBootstrapCustom >> installStubsAndInitialObjects [
	builder 
		initializeBootstrapEnvironment;
		createVMStubs;
		flushNewSpace;
		createInitialObjects
]

{ #category : #accessing }
PBBootstrapCustom >> instanceVariableMappingClass [
	self subclassResponsibility 
]

{ #category : #accessing }
PBBootstrapCustom >> languageDefinitionClass [
	^ self subclassResponsibility 
]

{ #category : #accessing }
PBBootstrapCustom >> originRepository [
	^ self pbRepository tonelFullRepository 
]

{ #category : #accessing }
PBBootstrapCustom >> pbRepository [
	^ pbRepository
]

{ #category : #accessing }
PBBootstrapCustom >> pbRepository: aPBRepository [ 
	pbRepository := aPBRepository 
]

{ #category : #'as yet unclassified' }
PBBootstrapCustom >> prepareEnvironmentForExportKeepingPackages: aListOfPackages [
	| allPackages |

	allPackages := self environment packages collect: #name.

	(allPackages reject: [ :x | aListOfPackages includes: x ])
		do: [ :x | 
			| p |
			p := self environment ask packageNamed: x.
			p extensionMethods do: [ :e | e methodClass removeLocalMethod: e ].
			p definedBehaviors
				do: [ :e | 
					self environment removeBehavior: e.
					self environment removeBehavior: e classSide
					].
			self environment removePackage: p].

	self environment cleanGlobalVariables.
	self environment addGlobalsNamed: #(#Smalltalk #SourceFiles #Transcript #Undeclared #Display #TextConstants  #Sensor #Processor #SystemOrganization).
	self environment clean

]
