"
I perform the Bootstrap process generating an image that contains only a specific list of packages
"
Class {
	#name : #PBBootstrapManual,
	#superclass : #PBBootstrapCustom,
	#category : #Pharo80Bootstrap
}

{ #category : #bootstrapping }
PBBootstrapManual >> bootstrap [
	"I should be excecuted only if my environment was set beforehand"
	ringEnvironment ifNil: [ Error signal: 'Ring environment must be set before bootstraping' ].
	PBStepStartedSignal log: 'Starting  Process.'.
	
	self prepareBootstrap.
	[self createImage ] on:AssertionFailure do: [ :e | e resume ].
	self initializeImage.
		
	PBStepFinishedSignal log: 'Process ended.'
	
]

{ #category : #'as yet unclassified' }
PBBootstrapManual >> builderClass [
	^ PBImageBuilderManualSpur5032bit 
]

{ #category : #'as yet unclassified' }
PBBootstrapManual >> createImage [

	builder := self builderClass new. "only available for 32 bits"
	builder versionInfo: versionInfo.
	builder imageFileReference: imageReference.
	builder systemDefinition: ringEnvironment.
	builder espellBackend instanceVariableMapping: (self instanceVariableMappingClass  onEnvironment: ringEnvironment ).
		
	builder bootstrapManual
]

{ #category : #'as yet unclassified' }
PBBootstrapManual >> instanceVariableMappingClass [
	^ PBInstanceVariableMappingPharoManual
]

{ #category : #accessing }
PBBootstrapManual >> languageDefinitionClass [
	^ PBLanguageDefinitionPharoManual
]

{ #category : #'as yet unclassified' }
PBBootstrapManual >> prepareBootstrap [
	self setDefaultOptions .
	"preparation steps for manual bootstrap"
	self ensureBaselineOfPharoBootstrap.
	"the next lines are from the original method 'PBBootstrap>>prepareEnvironmentForHermes"
	ringEnvironment fixProtoObjectClassSuperclass.
	ringEnvironment addGlobalsNamed: #(Smalltalk Transcript FileStream MacRomanTextConverter ChangeSet Character SourceFiles Processor Display Sensor UTF8TextConverter SystemOrganization Undeclared TextConstants).
	ringEnvironment clean.
	"end of fix"
	self prepareEnvironmentForExportKeepingPackages: #BaselineOfPharoBootstrap asClass kernelPackageNames, PBBuilder TestsForBootstrap .
]

{ #category : #bootstrapping }
PBBootstrapManual >> setDefaultOptions [
	| options |
	options := CommandLineArguments new.
	architecture := options optionAt: 'ARCH' ifAbsent: [ '32' ].
	buildNumber := options
		optionAt: 'BUILD_NUMBER'
		ifPresent: [ :read | Number readFrom: read ifFail: [ -1 ] ]
		ifAbsent: [ -1 ].
	versionInfo := options
		optionAt: 'VERSION_INFO'
		ifAbsent:
			[ "TODO: replace the next provisory value for the real git version info" 'v7.0.0-alpha-5014-gd40cba880' ].
	('Architecture: ' , architecture asString) traceCr.
	('BuildNumber: ' , buildNumber asString) traceCr.
	('VersionInfo: ' , versionInfo asString) traceCr.
	versionInfo := (PBVersionInfo fromLongGitDescribe: versionInfo)
		buildNumber: buildNumber;
		yourself
]
