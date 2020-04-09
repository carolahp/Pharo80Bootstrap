"
I perform the Bootstrap process generating an image that contains only a specific list of packages. I use the code from PharoCandle
"
Class {
	#name : #PBBootstrapCandle,
	#superclass : #PBBootstrapCustom,
	#category : #Pharo80Bootstrap
}

{ #category : #bootstrapping }
PBBootstrapCandle >> bootstrap [
	self prepareBootstrap.
	self createImage.
	"[self createImage ] on:AssertionFailure do: [ :e | e resume ].
	self initializeImage."
	
]

{ #category : #accessing }
PBBootstrapCandle >> builderClass [
	^ PBImageBuilderCandle  
]

{ #category : #accessing }
PBBootstrapCandle >> instanceVariableMappingClass [
	^ PBInstanceVariableMappingPharoCandle
]

{ #category : #accessing }
PBBootstrapCandle >> languageDefinitionClass [
	^ PBLanguageDefinitionPharoCandle
]

{ #category : #bootstrapping }
PBBootstrapCandle >> prepareBootstrap [
	self setDefaultOptions 
]

{ #category : #bootstrapping }
PBBootstrapCandle >> setDefaultOptions [
	| options |
	options := CommandLineArguments new.
	architecture := options optionAt: 'ARCH' ifAbsent: [ '32' ].
	buildNumber := '-1'.
	versionInfo := '-1'.
	('Architecture: ' , architecture) traceCr.
	('BuildNumber: ' , buildNumber) traceCr.
	('VersionInfo: ' , versionInfo) traceCr

	"versionInfo := (PBVersionInfo fromLongGitDescribe: versionInfo)
		buildNumber: buildNumber;
		yourself"
]
