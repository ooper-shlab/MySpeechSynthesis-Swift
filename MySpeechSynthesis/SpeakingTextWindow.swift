//
//  Document.swift
//  MySpeechSynthesis
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/7/25.
//  Copyright © 2015 OOPer (NAGATA, Atsuyuki). All rights reserved.
//

import Cocoa

typealias SRefCon = UnsafePointer<Void>

private let kWordCallbackParamPosition = "ParamPosition"
private let kWordCallbackParamLength = "ParamLength"

class SpeakingTextWindow: NSDocument, NSSpeechSynthesizerDelegate {
    
    
    // Main window outlets
    @IBOutlet private var fWindow: NSWindow!
    @IBOutlet private var fSpokenTextView: NSTextView!
    @IBOutlet private var fStartStopButton: NSButton!
    @IBOutlet private var fPauseContinueButton: NSButton!
    @IBOutlet private var fSaveAsFileButton: NSButton!
    
    // Options panel outlets
    @IBOutlet private var fImmediatelyRadioButton: NSButton!
    @IBOutlet private var fAfterWordRadioButton: NSButton!
    @IBOutlet private var fAfterSentenceRadioButton: NSButton!
    @IBOutlet private var fVoicesPopUpButton: NSPopUpButton!
    @IBOutlet private var fCharByCharCheckboxButton: NSButton!
    @IBOutlet private var fDigitByDigitCheckboxButton: NSButton!
    @IBOutlet private var fPhonemeModeCheckboxButton: NSButton!
    @IBOutlet private var fDumpPhonemesButton: NSButton!
    @IBOutlet private var fUseDictionaryButton: NSButton!
    
    // Parameters panel outlets
    @IBOutlet private var fRateDefaultEditableField: NSTextField!
    @IBOutlet private var fPitchBaseDefaultEditableField: NSTextField!
    @IBOutlet private var fPitchModDefaultEditableField: NSTextField!
    @IBOutlet private var fVolumeDefaultEditableField: NSTextField!
    @IBOutlet private var fRateCurrentStaticField: NSTextField!
    @IBOutlet private var fPitchBaseCurrentStaticField: NSTextField!
    @IBOutlet private var fPitchModCurrentStaticField: NSTextField!
    @IBOutlet private var fVolumeCurrentStaticField: NSTextField!
    @IBOutlet private var fResetButton: NSButton!
    
    // Callbacks panel outlets
    @IBOutlet private var fHandleWordCallbacksCheckboxButton: NSButton!
    @IBOutlet private var fHandlePhonemeCallbacksCheckboxButton: NSButton!
    @IBOutlet private var fHandleSyncCallbacksCheckboxButton: NSButton!
    @IBOutlet private var fHandleErrorCallbacksCheckboxButton: NSButton!
    @IBOutlet private var fHandleSpeechDoneCallbacksCheckboxButton: NSButton!
    @IBOutlet private var fHandleTextDoneCallbacksCheckboxButton: NSButton!
    @IBOutlet private var fCharacterView: SpeakingCharacterView!
    
    // Misc. instance variables
    private var fOrgSelectionRange: NSRange = NSRange()
//    private var fSelectedVoiceID: OSType = 0
//    private var fSelectedVoiceCreator: OSType = 0
//    private var fCurSpeechChannel: SpeechChannel = nil
    private var selectedVoice: String = NSSpeechSynthesizer.defaultVoice()
    private var speechSynthesizer: NSSpeechSynthesizer = NSSpeechSynthesizer()
    private var fOffsetToSpokenText: Int = 0
    private var fLastErrorCode: Int = 0
    private var fLastSpeakingValue: Bool = false
    private var fLastPausedValue: Bool = false
    private var fCurrentlySpeaking: Bool = false
    private var fCurrentlyPaused: Bool = false
    private var fSavingToFile: Bool = false
    private var fTextData: NSData!
    private let fErrorFormatString: String = NSLocalizedString("Error #%d (0x%0X) returned.", comment: "Error #%d (0x%0X) returned.")
    
    // Getters/Setters
    private var textDataType: String = ""
    
    
    //MARK: - Constants
    
    private let kPlainTextDataTypeString = "Plain Text"
    private let kDefaultWindowTextString = "Welcome to Cocoa Speech Synthesis Example. " +
    "This application provides an example of using Apple's speech synthesis technology in a Cocoa-based application."
    
    private let kErrorCallbackParamPosition = "ParamPosition"
    private let kErrorCallbackParamError = "ParamError"
    
    
    //MARK: - Prototypes
    
    
    //MARK: -
    
    /*----------------------------------------------------------------------------------------
    init
    
    Set the default text of the window.
    ----------------------------------------------------------------------------------------*/
    override init() {
        super.init()
        // set our default window text
        kDefaultWindowTextString.withCString {p -> Void in
            self.textData = NSData(bytes: p, length: Int(strlen(p)))
        }
        self.textDataType = kPlainTextDataTypeString
        
    }
    
    /*----------------------------------------------------------------------------------------
    close
    
    Make sure to stop speech when closing.
    ----------------------------------------------------------------------------------------*/
    override func close() {
        self.startStopButtonPressed(fStartStopButton)
    }
    
    /*----------------------------------------------------------------------------------------
    setTextData:
    
    Set our text data variable and update text in window if showing.
    ----------------------------------------------------------------------------------------*/
    private var textData: NSData {
        set(theData) {
            fTextData = theData
            // If the window is showing, update the text view.
            if fSpokenTextView != nil {
                if self.textDataType == "RTF Document" {
                    fSpokenTextView.replaceCharactersInRange(NSRange(0..<fSpokenTextView.string!.utf16.count), withRTF: self.textData)
                } else {
                    fSpokenTextView.replaceCharactersInRange(NSRange(0..<fSpokenTextView.string!.utf16.count),
                        withString: NSString(data: self.textData, encoding: NSUTF8StringEncoding)! as String)
                }
            }
        }
        
        /*----------------------------------------------------------------------------------------
        textData
        
        Returns autoreleased copy of text data.
        ----------------------------------------------------------------------------------------*/
        get {
            return fTextData.copy() as! NSData
        }
    }
    
    /*----------------------------------------------------------------------------------------
    setTextDataType:
    
    Set our text data type variable.
    ----------------------------------------------------------------------------------------*/
    //- (void)setTextDataType:(NSString *)theType {
    //    fTextDataType = theType;
    //} // setTextDataType
    //
    /*----------------------------------------------------------------------------------------
    textDataType
    
    Returns autoreleased copy of text data.
    ----------------------------------------------------------------------------------------*/
    //- (NSString *)textDataType {
    //    return ([fTextDataType copy]);
    //}
    
    /*----------------------------------------------------------------------------------------
    textDataType
    
    Returns reference to character view for callbacks.
    ----------------------------------------------------------------------------------------*/
    var characterView: SpeakingCharacterView! {
        return fCharacterView
    }
    
    /*----------------------------------------------------------------------------------------
    shouldDisplayWordCallbacks
    
    Returns true if user has chosen to have words hightlight during synthesis.
    ----------------------------------------------------------------------------------------*/
    private var shouldDisplayWordCallbacks: Bool {
        return fHandleWordCallbacksCheckboxButton.intValue != 0
    }
    
    /*----------------------------------------------------------------------------------------
    shouldDisplayPhonemeCallbacks
    
    Returns true if user has chosen to the character animate phonemes during synthesis.
    ----------------------------------------------------------------------------------------*/
    private var shouldDisplayPhonemeCallbacks: Bool {
        return fHandlePhonemeCallbacksCheckboxButton.intValue != 0
    }
    
    /*----------------------------------------------------------------------------------------
    shouldDisplayErrorCallbacks
    
    Returns true if user has chosen to have an alert appear in response to an error callback.
    ----------------------------------------------------------------------------------------*/
    private var shouldDisplayErrorCallbacks: Bool {
        return fHandleErrorCallbacksCheckboxButton.intValue != 0
    }
    
    /*----------------------------------------------------------------------------------------
    shouldDisplaySyncCallbacks
    
    Returns true if user has chosen to have an alert appear in response to an sync callback.
    ----------------------------------------------------------------------------------------*/
    private var shouldDisplaySyncCallbacks: Bool {
        return fHandleSyncCallbacksCheckboxButton.intValue != 0
    }
    
    /*----------------------------------------------------------------------------------------
    shouldDisplaySpeechDoneCallbacks
    
    Returns true if user has chosen to have an alert appear when synthesis is finished.
    ----------------------------------------------------------------------------------------*/
    private var shouldDisplaySpeechDoneCallbacks: Bool {
        return fHandleSpeechDoneCallbacksCheckboxButton.intValue != 0
    }
    
    /*----------------------------------------------------------------------------------------
    shouldDisplayTextDoneCallbacks
    
    Returns true if user has chosen to have an alert appear when text processing is finished.
    ----------------------------------------------------------------------------------------*/
    private var shouldDisplayTextDoneCallbacks: Bool {
        return fHandleTextDoneCallbacksCheckboxButton.intValue != 0
    }
    
    /*----------------------------------------------------------------------------------------
    updateSpeakingControlState
    
    This routine is called when appropriate to update the Start/Stop Speaking,
    Pause/Continue Speaking buttons.
    ----------------------------------------------------------------------------------------*/
    private func updateSpeakingControlState() {
        // Update controls based on speaking state
        fSaveAsFileButton.enabled = !fCurrentlySpeaking
        fPauseContinueButton.enabled = fCurrentlySpeaking
        fStartStopButton.enabled = !fCurrentlyPaused
        if fCurrentlySpeaking {
            fStartStopButton.title = NSLocalizedString("Stop Speaking", comment: "Stop Speaking")
            fPauseContinueButton.title = NSLocalizedString("Pause Speaking", comment: "Pause Speaking")
        } else {
            fStartStopButton.title = NSLocalizedString("Start Speaking", comment: "Start Speaking")
            fSpokenTextView.setSelectedRange(fOrgSelectionRange);  // Set selection length to zero.
        }
        if fCurrentlyPaused {
            fPauseContinueButton.title = NSLocalizedString("Continue Speaking", comment: "Continue Speaking")
        } else {
            fPauseContinueButton.title = NSLocalizedString("Pause Speaking", comment: "Pause Speaking")
        }
        
        self.enableOptionsForSpeakingState(fCurrentlySpeaking)
        
        // update parameter fields
        do {
            fRateCurrentStaticField.doubleValue = try speechSynthesizer.objectForProperty(NSSpeechRateProperty).doubleValue!
            fPitchBaseCurrentStaticField.doubleValue = try speechSynthesizer.objectForProperty(NSSpeechPitchBaseProperty).doubleValue!
            fPitchModCurrentStaticField.doubleValue = try speechSynthesizer.objectForProperty(NSSpeechPitchModProperty).doubleValue!
            fVolumeCurrentStaticField.doubleValue = try speechSynthesizer.objectForProperty(NSSpeechVolumeProperty).doubleValue!
        } catch _ {}
    }
    
    /*----------------------------------------------------------------------------------------
    highlightWordWithParams:
    
    Highlights the word currently being spoken based on text position and text length
    provided in the word callback routine.
    ----------------------------------------------------------------------------------------*/
    private func highlightWordWithRange(range: NSRange) {
        let selectionPosition = range.location + fOffsetToSpokenText
        let wordLength = range.length
        
        fSpokenTextView.scrollRangeToVisible(NSMakeRange(selectionPosition, wordLength))
        fSpokenTextView.setSelectedRange(NSMakeRange(selectionPosition, wordLength))
        fSpokenTextView.display()
    }
    
    /*----------------------------------------------------------------------------------------
    displayErrorAlertWithParams:
    
    Displays an alert describing a text processing error provided in the error callback.
    ----------------------------------------------------------------------------------------*/
    private func displayErrorAlertWithParams(params: [String: AnyObject]) {
        let errorPosition = params[kErrorCallbackParamPosition]!.integerValue + fOffsetToSpokenText
        let errorCode = params[kErrorCallbackParamError]!.integerValue
        
        if errorCode != fLastErrorCode {
            
            // Tell engine to pause while we display this dialog.
            speechSynthesizer.pauseSpeakingAtBoundary(NSSpeechBoundary.ImmediateBoundary)
            
            // Select offending character
            fSpokenTextView.setSelectedRange(NSMakeRange(errorPosition, 1))
            fSpokenTextView.display()
            
            // Display error alert, and stop or continue based on user's desires
            let messageFormat = NSLocalizedString("Error #%ld occurred at position %ld in the text.",
                comment: "Error #%ld occurred at position %ld in the text.")
            let theMessageStr = String(format: messageFormat,
                Int(errorCode), Int(errorPosition))
            let response = self.runAlertPanelWithTitle("Text Processing Error",
                message: theMessageStr,
                buttonTitles: ["Stop", "Continue"])
            if response == NSAlertFirstButtonReturn {
                self.startStopButtonPressed(fStartStopButton)
            } else {
                speechSynthesizer.continueSpeaking()
            }
            
            fLastErrorCode = errorCode
        }
    }
    
    /*----------------------------------------------------------------------------------------
    displaySyncAlertWithMessage:
    
    Displays an alert with information about a sync command in response to a sync callback.
    ----------------------------------------------------------------------------------------*/
    func displaySyncAlertWithMessage(message: String) {
        var theMessageStr = ""
        
        // Tell engine to pause while we display this dialog.
        speechSynthesizer.pauseSpeakingAtBoundary(NSSpeechBoundary.ImmediateBoundary)
        
        // Display error alert and stop or continue based on user's desires
        let messageFormat = NSLocalizedString("Sync embedded command was discovered containing message '%@'.",
            comment: "Sync embedded command was discovered containing message '%@'.")
        theMessageStr = String(format: messageFormat, message)
        
        let alertButtonClicked =
        self.runAlertPanelWithTitle("Sync Callback", message: theMessageStr, buttonTitles: ["Stop", "Continue"])
        if alertButtonClicked == 1 {
            self.startStopButtonPressed(fStartStopButton)
        } else {
            speechSynthesizer.continueSpeaking()
        }
    }
    
    /*----------------------------------------------------------------------------------------
    speechIsDone
    
    Updates user interface and optionally displays an alert when generation of speech is
    finish.
    ----------------------------------------------------------------------------------------*/
    func speechIsDone() {
        fCurrentlySpeaking = false
        self.updateSpeakingControlState()
        self.enableCallbackControlsBasedOnSavingToFileFlag(false)
        if self.shouldDisplaySpeechDoneCallbacks {
            self.runAlertPanelWithTitle("Speech Done",
                message: "Generation of synthesized speech is finished.",
                buttonTitles: ["OK"])
        }
    }
    
//    /*----------------------------------------------------------------------------------------
//    displayTextDoneAlert
//    
//    Displays an alert in response to a text done callback.
//    ----------------------------------------------------------------------------------------*/
//    func displayTextDoneAlert() {
//        
//        // Tell engine to pause while we display this dialog.
//        speechSynthesizer.pauseSpeakingAtBoundary(NSSpeechBoundary.ImmediateBoundary)
//        
//        // Display error alert, and stop or continue based on user's desires
//        let response = self.runAlertPanelWithTitle("Text Done Callback",
//            message: "Processing of the text has completed.",
//            buttonTitles: ["Stop", "Continue"])
//        if response == NSAlertFirstButtonReturn {
//            self.startStopButtonPressed(fStartStopButton)
//        } else {
//            speechSynthesizer.continueSpeaking()
//        }
//    }
    
    /*----------------------------------------------------------------------------------------
    startStopButtonPressed:
    
    An action method called when the user clicks the "Start Speaking"/"Stop Speaking"
    button.	 We either start or stop speaking based on the current speaking state.
    ----------------------------------------------------------------------------------------*/
    @IBAction func startStopButtonPressed(sender: NSButton) {
        
        if fCurrentlySpeaking {
            var whereToStop: NSSpeechBoundary = .ImmediateBoundary
            
            // Grab where to stop at value from radio buttons
            if fAfterWordRadioButton.intValue != 0 {
                whereToStop = .WordBoundary
            } else if fAfterSentenceRadioButton.intValue != 0 {
                whereToStop = .SentenceBoundary
            }
            if whereToStop == .ImmediateBoundary {
                // NOTE:	We could just call StopSpeechAt with kImmediate, but for test purposes
                // we exercise the StopSpeech routine.
                speechSynthesizer.stopSpeaking()
            } else {
                speechSynthesizer.stopSpeakingAtBoundary(whereToStop)
            }
            
            fCurrentlySpeaking = false
            self.updateSpeakingControlState()
        } else {
            self.startSpeakingTextViewToURL(nil)
        }
    }
    
    /*----------------------------------------------------------------------------------------
    saveAsButtonPressed:
    
    An action method called when the user clicks the "Save As File" button.	 We ask user
    to specify where to save the file, then start speaking to this file.
    ----------------------------------------------------------------------------------------*/
    @IBAction func saveAsButtonPressed(sender: AnyObject) {
        
        let theSavePanel = NSSavePanel()
        
        theSavePanel.prompt = NSLocalizedString("Save", comment: "Save")
        theSavePanel.nameFieldStringValue = "Synthesized Speech.aiff"
        if theSavePanel.runModal() == NSFileHandlingPanelOKButton {
            let selectedFileURL = theSavePanel.URL
            self.startSpeakingTextViewToURL(selectedFileURL)
        }
    }
    
    /*----------------------------------------------------------------------------------------
    startSpeakingTextViewToURL:
    
    This method sets up the speech channel and begins the speech synthesis
    process, optionally speaking to a file instead playing through the speakers.
    ----------------------------------------------------------------------------------------*/
    private func startSpeakingTextViewToURL(url: NSURL?) {
        var theViewText: String? = nil
        
        // Grab the selection substring, or if no selection then grab entire text.
        fOrgSelectionRange = fSpokenTextView.selectedRange()
        if fOrgSelectionRange.length == 0 {
            theViewText = fSpokenTextView.string
            fOffsetToSpokenText = 0
        } else {
            theViewText = (fSpokenTextView.string ?? "" as NSString).substringWithRange(fOrgSelectionRange)
            fOffsetToSpokenText = fOrgSelectionRange.location
        }
        
        // Setup our callbacks
        fSavingToFile = (url != nil)
        speechSynthesizer.delegate = self
        
        // Set URL to save file to disk
        do {
            try speechSynthesizer.setObject(url, forProperty: NSSpeechOutputToFileURLProperty)
        } catch _ {}
        
        // Convert NSString to cString.
        // We want the text view the active view.  Also saves any parameters currently being edited.
        fWindow.makeFirstResponder(fSpokenTextView)
        
        let success = speechSynthesizer.startSpeakingString(theViewText!)
        if success {
            // Update our vars
            fLastErrorCode = 0
            fLastSpeakingValue = false
            fLastPausedValue = false
            fCurrentlySpeaking = true
            fCurrentlyPaused = false
            self.updateSpeakingControlState()
        } else {
            self.runAlertPanelWithTitle("SpeakText",
                message: "Error in startSpeakingString",
                buttonTitles: ["Oh?"])
        }
        
        self.enableCallbackControlsBasedOnSavingToFileFlag(fSavingToFile)
    }
    
    /*----------------------------------------------------------------------------------------
    pauseContinueButtonPressed:
    
    An action method called when the user clicks the "Pause Speaking"/"Continue Speaking"
    button.	 We either pause or continue speaking based on the current speaking state.
    ----------------------------------------------------------------------------------------*/
    @IBAction func pauseContinueButtonPressed(sender: AnyObject) {
        
        if fCurrentlyPaused {
            // We want the text view the active view.  Also saves any parameters currently being edited.
            fWindow.makeFirstResponder(fSpokenTextView)
            
            speechSynthesizer.continueSpeaking()
            
            fCurrentlyPaused = false
            self.updateSpeakingControlState()
        } else {
            var whereToPause: NSSpeechBoundary = .ImmediateBoundary
            
            // Figure out where to stop from radio buttons
            if fAfterSentenceRadioButton.intValue != 0 {
                whereToPause = .WordBoundary
            } else if fAfterSentenceRadioButton.intValue != 0 {
                whereToPause = .SentenceBoundary
            }
            
            speechSynthesizer.pauseSpeakingAtBoundary(whereToPause)
            
            fCurrentlyPaused = true
            self.updateSpeakingControlState()
        }
    }
    
    /*----------------------------------------------------------------------------------------
    voicePopupSelected:
    
    An action method called when the user selects a new voice from the Voices pop-up
    menu.  We ask the speech channel to use the selected voice.	 If the current
    speech channel cannot use the selected voice, we close and open new speech
    channel with the selecte voice.
    ----------------------------------------------------------------------------------------*/
    @IBAction func voicePopupSelected(sender: NSPopUpButton) {
        let theSelectedMenuIndex = sender.indexOfSelectedItem
        
        let voice: String
        if theSelectedMenuIndex == 0 {
            // Use the default voice from preferences.
            // Our only choice is to close and reopen the speech channel to get the default voice.
            voice = NSSpeechSynthesizer.defaultVoice()
        } else {
            // Use the voice the user selected.
            voice = NSSpeechSynthesizer.availableVoices()[sender.indexOfSelectedItem - 1]
        }
        speechSynthesizer.setVoice(voice)
        self.selectedVoice = voice
        // Set editable default fields
        self.fillInEditableParameterFields()
    }
    
    /*----------------------------------------------------------------------------------------
    charByCharCheckboxSelected:
    
    An action method called when the user checks/unchecks the Character-By-Character
    mode checkbox.	We tell the speech channel to use this setting.
    ----------------------------------------------------------------------------------------*/
    @IBAction func charByCharCheckboxSelected(sender: AnyObject) {
        
        do {
            if fCharByCharCheckboxButton.intValue != 0 {
                try speechSynthesizer.setObject(NSSpeechModeLiteral, forProperty: NSSpeechCharacterModeProperty)
            } else {
                try speechSynthesizer.setObject(NSSpeechModeNormal, forProperty: NSSpeechCharacterModeProperty)
            }
        } catch let error as NSError {
            self.runAlertPanelWithTitle("SetSpeechProperty(NSSpeechCharacterModeProperty)",
                message: String(format: fErrorFormatString, error, error),
                buttonTitles: ["Oh?"])
        }
    }
    
    /*----------------------------------------------------------------------------------------
    digitByDigitCheckboxSelected:
    
    An action method called when the user checks/unchecks the Digit-By-Digit
    mode checkbox.	We tell the speech channel to use this setting.
    ----------------------------------------------------------------------------------------*/
    @IBAction func digitByDigitCheckboxSelected(sender: AnyObject) {
        
        do {
            if fDigitByDigitCheckboxButton.intValue != 0 {
                try speechSynthesizer.setObject(NSSpeechModeLiteral, forProperty: NSSpeechNumberModeProperty)
            } else {
                try speechSynthesizer.setObject(NSSpeechModeNormal, forProperty: NSSpeechNumberModeProperty)
            }
        } catch let error as NSError {
            self.runAlertPanelWithTitle("SetSpeechProperty(NSSpeechNumberModeProperty)",
                message: String(format: fErrorFormatString, error, error),
                buttonTitles: ["Oh?"])
        }
    }
    
    /*----------------------------------------------------------------------------------------
    phonemeModeCheckboxSelected:
    
    An action method called when the user checks/unchecks the Phoneme input
    mode checkbox.	We tell the speech channel to use this setting.
    ----------------------------------------------------------------------------------------*/
    @IBAction func phonemeModeCheckboxSelected(sender:AnyObject) {
        
        do {
            if fPhonemeModeCheckboxButton.intValue != 0 {
                try speechSynthesizer.setObject(NSSpeechModePhoneme, forProperty: NSSpeechInputModeProperty)
            } else {
                try speechSynthesizer.setObject(NSSpeechModeText, forProperty: NSSpeechInputModeProperty)
            }
        } catch let error as NSError {
            self.runAlertPanelWithTitle("SetSpeechProperty(NSSpeechInputModeProperty)",
                message: String(format: fErrorFormatString, error, error),
                buttonTitles: ["Oh?"])
        }
    }
    
    /*----------------------------------------------------------------------------------------
    dumpPhonemesSelected:
    
    An action method called when the user clicks the Dump Phonemes button.	We ask
    the speech channel for a phoneme representation of the window text then save the
    result to a text file at a location determined by the user.
    ----------------------------------------------------------------------------------------*/
    @IBAction func dumpPhonemesSelected(sender: AnyObject) {
        let panel = NSSavePanel()
        
        if panel.runModal() != 0 && panel.URL != nil {
            // Get and speech text
            let phonemesString = speechSynthesizer.phonemesFromText(fSpokenTextView.string!)
            do {
                try phonemesString.writeToURL(panel.URL!, atomically: true, encoding: NSUTF8StringEncoding)
            } catch let nsError as NSError {
                let messageFormat = NSLocalizedString("writeToURL: '%@' error: %@",
                    comment: "writeToURL: '%@' error: %@")
                self.runAlertPanelWithTitle("CopyPhonemesFromText",
                    message: String(format: messageFormat, panel.URL!, nsError),
                    buttonTitles: ["Oh?"])
            }
        }
    }
    
    /*----------------------------------------------------------------------------------------
    useDictionarySelected:
    
    An action method called when the user clicks the "Use Dictionary…" button.
    ----------------------------------------------------------------------------------------*/
    @IBAction func useDictionarySelected(sender: AnyObject) {
        // Open file.
        let panel = NSOpenPanel()
        
        panel.message = "Choose a dictionary file"
        panel.allowedFileTypes = ["xml", "plist"]
        
        panel.allowsMultipleSelection = true
        
        if panel.runModal() != 0 {
            for fileURL in panel.URLs {
                // Read dictionary file into NSData object.
                if let speechDictionary = NSDictionary(contentsOfURL: fileURL) as? [String: AnyObject] {
                    speechSynthesizer.addSpeechDictionary(speechDictionary)
                } else {
                    let messageFormat = NSLocalizedString("dictionaryWithContentsOfURL:'%@' returned NULL",
                        comment: "dictionaryWithContentsOfURL:'%@' returned NULL")
                    self.runAlertPanelWithTitle("CopyPhonemesFromText",
                        message: String(format: messageFormat, fileURL.path!),
                        buttonTitles: ["Oh?"])
                }
            }
        }
    }
    
    /*----------------------------------------------------------------------------------------
    rateChanged:
    
    An action method called when the user changes the rate field.  We tell the speech
    channel to use this setting.
    ----------------------------------------------------------------------------------------*/
    @IBAction func rateChanged(sender: AnyObject) {
        speechSynthesizer.rate = fRateDefaultEditableField.floatValue
    }
    
    /*----------------------------------------------------------------------------------------
    pitchBaseChanged:
    
    An action method called when the user changes the pitch base field.	 We tell the speech
    channel to use this setting.
    ----------------------------------------------------------------------------------------*/
    @IBAction func pitchBaseChanged(sender: AnyObject) {
        do {
            try speechSynthesizer.setObject(fPitchBaseDefaultEditableField.doubleValue, forProperty: NSSpeechPitchBaseProperty)
            fPitchBaseCurrentStaticField.doubleValue = fPitchBaseDefaultEditableField.doubleValue
        } catch let error as NSError {
            self.runAlertPanelWithTitle("SetSpeechPitch",
                message: String(format: fErrorFormatString, error, error),
                buttonTitles: ["Oh?"])
        }
    }
    
    /*----------------------------------------------------------------------------------------
    pitchModChanged:
    
    An action method called when the user changes the pitch modulation field.  We tell
    the speech channel to use this setting.
    ----------------------------------------------------------------------------------------*/
    @IBAction func pitchModChanged(sender: AnyObject) {
        do {
            try speechSynthesizer.setObject(fPitchModDefaultEditableField.doubleValue, forProperty: NSSpeechPitchModProperty)
            fPitchModCurrentStaticField.doubleValue = fPitchModDefaultEditableField.doubleValue
        } catch let error as NSError {
            self.runAlertPanelWithTitle("SetSpeechProperty(kSpeechPitchModProperty)",
                message: String(format: fErrorFormatString, error, error),
                buttonTitles: ["Oh?"])
        }
    }
    
    /*----------------------------------------------------------------------------------------
    volumeChanged:
    
    An action method called when the user changes the volume field.	 We tell
    the speech channel to use this setting.
    ----------------------------------------------------------------------------------------*/
    @IBAction func volumeChanged(sender: AnyObject) {
        speechSynthesizer.volume = fVolumeDefaultEditableField.floatValue
    }
    
    /*----------------------------------------------------------------------------------------
    resetSelected:
    
    An action method called when the user clicks the Use Defaults button.  We tell
    the speech channel to use this the default settings.
    ----------------------------------------------------------------------------------------*/
    @IBAction func resetSelected(sender: AnyObject) {
        do {
            try speechSynthesizer.setObject(nil, forProperty: NSSpeechResetProperty)
            self.fillInEditableParameterFields()
        } catch let error as NSError {
            self.runAlertPanelWithTitle("SetSpeechProperty(NSSpeechResetProperty)",
                message: String(format: fErrorFormatString, error, error),
                buttonTitles: ["Oh?"])
        }
    }
    
    @IBAction func wordCallbacksButtonPressed(sender: AnyObject) {
        if fHandleWordCallbacksCheckboxButton.intValue == 0 {
            fSpokenTextView.setSelectedRange(fOrgSelectionRange)
        }
    }
    
    @IBAction func phonemeCallbacksButtonPressed(sender: AnyObject) {
        if fHandlePhonemeCallbacksCheckboxButton.intValue != 0 {
            characterView?.setExpression(.Idle)
        } else {
            characterView?.setExpression(.Sleep)
        }
    }
    
    /*----------------------------------------------------------------------------------------
    enableOptionsForSpeakingState:
    
    Updates controls in the Option tab panel based on the passed speakingNow flag.
    ----------------------------------------------------------------------------------------*/
    private func enableOptionsForSpeakingState(speakingNow: Bool) {
        fVoicesPopUpButton.enabled = !speakingNow
        fCharByCharCheckboxButton.enabled = !speakingNow
        fDigitByDigitCheckboxButton.enabled = !speakingNow
        fPhonemeModeCheckboxButton.enabled = !speakingNow
        fDumpPhonemesButton.enabled = !speakingNow
        fUseDictionaryButton.enabled = !speakingNow
    }
    
    /*----------------------------------------------------------------------------------------
    enableCallbackControlsForSavingToFile:
    
    Updates controls in the Callback tab panel based on the passed savingToFile flag.
    ----------------------------------------------------------------------------------------*/
    private func enableCallbackControlsBasedOnSavingToFileFlag(savingToFile: Bool) {
        fHandleWordCallbacksCheckboxButton.enabled = !savingToFile
        fHandlePhonemeCallbacksCheckboxButton.enabled = !savingToFile
        fHandleSyncCallbacksCheckboxButton.enabled = !savingToFile
        fHandleErrorCallbacksCheckboxButton.enabled = !savingToFile
        fHandleTextDoneCallbacksCheckboxButton.enabled = false//!savingToFile
        if savingToFile || fHandlePhonemeCallbacksCheckboxButton.intValue == 0 {
            characterView?.setExpression(.Sleep)
        } else {
            characterView?.setExpression(.Idle)
        }
    }
    
    /*----------------------------------------------------------------------------------------
    fillInEditableParameterFields
    
    Updates "Current" fields in the Parameters tab panel based on the current state of the
    speech channel.
    ----------------------------------------------------------------------------------------*/
    private func fillInEditableParameterFields() {
        var tempDoubleValue = 0.0
        
        tempDoubleValue = Double(speechSynthesizer.rate)
        
        fRateDefaultEditableField.doubleValue = tempDoubleValue
        fRateCurrentStaticField.doubleValue = tempDoubleValue
        
        do {
            tempDoubleValue = try speechSynthesizer.objectForProperty(NSSpeechPitchBaseProperty).doubleValue!
        } catch _ {
            tempDoubleValue = 0.0
        }
        fPitchBaseDefaultEditableField.doubleValue = tempDoubleValue
        fPitchBaseCurrentStaticField.doubleValue = tempDoubleValue
        
        do {
            tempDoubleValue = try speechSynthesizer.objectForProperty(NSSpeechPitchModProperty).doubleValue!
        } catch _ {
            tempDoubleValue = 0.0
        }
        fPitchModDefaultEditableField.doubleValue = tempDoubleValue
        fPitchModCurrentStaticField.doubleValue = tempDoubleValue
        
        tempDoubleValue = Double(speechSynthesizer.volume)
        fVolumeDefaultEditableField.doubleValue = tempDoubleValue
        fVolumeCurrentStaticField.doubleValue = tempDoubleValue
    }
    
//    /*----------------------------------------------------------------------------------------
//    createNewSpeechChannel:
//    
//    Create a new speech channel for the given voice spec.  A nil voice spec pointer
//    causes the speech channel to use the default voice.	 Any existing speech channel
//    for this window is closed first.
//    ----------------------------------------------------------------------------------------*/
//    private func createNewSpeechChannel(voiceSpec: UnsafeMutablePointer<VoiceSpec>) -> OSErr {
//        var theErr: OSErr = OSErr(noErr)
//        
//        // Dispose of the current one, if present.
//        if fCurSpeechChannel != nil {
//            theErr = DisposeSpeechChannel(fCurSpeechChannel)
//            if theErr != OSErr(noErr) {
//                self.runAlertPanelWithTitle("DisposeSpeechChannel",
//                    message: String(format: fErrorFormatString, Int32(theErr), Int32(theErr)),
//                    buttonTitles: ["Oh?"])
//            }
//            
//            fCurSpeechChannel = nil
//        }
//        // Create a speech channel
//        if theErr == OSErr(noErr) {
//            theErr = NewSpeechChannel(voiceSpec, &fCurSpeechChannel)
//            if theErr != OSErr(noErr) {
//                self.runAlertPanelWithTitle("NewSpeechChannel",
//                    message: String(format: fErrorFormatString, Int32(theErr), Int32(theErr)),
//                    buttonTitles: ["Oh?"])
//            }
//        }
//        // Setup our refcon to the document controller object so we have access within our Speech callbacks
//        if theErr == OSErr(noErr) {
//            //### !!!check memory usage!!!
//            theErr = SetSpeechProperty(fCurSpeechChannel, kSpeechRefConProperty, unsafeBitCast(self, Int.self))
//            if theErr != OSErr(noErr) {
//                self.runAlertPanelWithTitle("SetSpeechProperty(kSpeechRefConProperty)",
//                    message: String(format: fErrorFormatString, Int32(theErr), Int32(theErr)),
//                    buttonTitles: ["Oh?"])
//            }
//        }
//        
//        return theErr
//    }
    
    
    //MARK: - Window
    
    /*----------------------------------------------------------------------------------------
    awakeFromNib
    
    This routine is call once right after our nib file is loaded.  We build our voices
    pop-up menu, create a new speech channel and update our window using parameters from
    the new speech channel.
    ----------------------------------------------------------------------------------------*/
    override func awakeFromNib() {
        
        // Build the Voices pop-up menu
        var voiceFoundAndSelected = false
        
        // Delete the existing voices from the bottom of the menu.
        while fVoicesPopUpButton.numberOfItems > 2 {
            fVoicesPopUpButton.removeItemAtIndex(2)
        }
        
        // Ask TTS API for each available voicez
        let voices = NSSpeechSynthesizer.availableVoices()
        for (voiceIndex, voice) in voices.enumerate() {
            let voiceAttr = NSSpeechSynthesizer.attributesForVoice(voice)
            let theVoiceName = voiceAttr[NSVoiceName] as! String? ?? voice
            fVoicesPopUpButton.addItemWithTitle(theVoiceName)
            // Selected this item if it matches our default voice spec.
            if voice == self.selectedVoice {
                fVoicesPopUpButton.selectItemAtIndex(Int(voiceIndex) + 1)
                voiceFoundAndSelected = true
            }
        }
        // User preference default if problems.
        if !voiceFoundAndSelected && voices.count >= 1 {
            // Update our object fields with the first voice
            self.selectedVoice = NSSpeechSynthesizer.defaultVoice()
            
            fVoicesPopUpButton.selectItemAtIndex(0)
        }
        
        // Create Speech Channel configured with our desired options and callbacks
        
        // Set editable default fields
        self.fillInEditableParameterFields()
        
        // Enable buttons appropriatelly
        fStartStopButton.enabled = true
        fPauseContinueButton.enabled = false
        fSaveAsFileButton.enabled = true
        fHandleTextDoneCallbacksCheckboxButton.enabled = false //###
        
        // Set starting expresison on animated character
        self.phonemeCallbacksButtonPressed(fHandlePhonemeCallbacksCheckboxButton)
    }
    
    /*----------------------------------------------------------------------------------------
    windowNibName
    
    Part of the NSDocument support. Called by NSDocument to return the nib file name of
    the document.
    ----------------------------------------------------------------------------------------*/
    override var windowNibName: String {
        return "SpeakingTextWindow"
    }
    
    /*----------------------------------------------------------------------------------------
    windowControllerDidLoadNib:
    
    Part of the NSDocument support. Called by NSDocument after the nib has been loaded
    to udpate window as appropriate.
    ----------------------------------------------------------------------------------------*/
    override func windowControllerDidLoadNib(aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        // Update the window text from data
        if self.textDataType == "RTF Document" {
            fSpokenTextView.replaceCharactersInRange(NSRange(0..<fSpokenTextView.string!.utf16.count), withRTF: self.textData)
        } else {
            fSpokenTextView.replaceCharactersInRange(NSRange(0..<fSpokenTextView.string!.utf16.count),
                withString: NSString(data: self.textData, encoding: NSUTF8StringEncoding)! as String)
        }
    }
    
    
    //MARK: - NSDocument
    
    /*----------------------------------------------------------------------------------------
    dataRepresentationOfType:
    
    Part of the NSDocument support. Called by NSDocument to wrote the document.
    ----------------------------------------------------------------------------------------*/
    override func dataOfType(aType: String) throws -> NSData {
        // Write text to file.
        if aType == "RTF Document" {
            self.textData = fSpokenTextView.RTFFromRange(NSRange(0..<fSpokenTextView.string!.utf16.count))!
        } else {
            self.textData = NSData(bytes: fSpokenTextView.string!, length: fSpokenTextView.string!.utf8.count)
        }
        
        return self.textData
    }
    
    /*----------------------------------------------------------------------------------------
    loadDataRepresentation: ofType:
    
    Part of the NSDocument support. Called by NSDocument to read the document.
    ----------------------------------------------------------------------------------------*/
    override func readFromData(data: NSData, ofType aType: String) throws {
        // Read the opened file.
        self.textData = data
        self.textDataType = aType
        
    }
    
    
    //MARK: - Utilities
    
    /*----------------------------------------------------------------------------------------
    simple replacement method for NSRunAlertPanel
    ----------------------------------------------------------------------------------------*/
    private func runAlertPanelWithTitle(inTitle: String,
        message inMessage: String,
        buttonTitles inButtonTitles: [String]) -> NSModalResponse
    {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString(inTitle, comment: inTitle)
        alert.informativeText = NSLocalizedString(inMessage, comment: inMessage)
        for buttonTitle in inButtonTitles {
            alert.addButtonWithTitle(NSLocalizedString(buttonTitle, comment: buttonTitle))
        }
        return alert.runModal()
    }
    
    
    //MARK: - Callback routines
    
    //
    // AN IMPORTANT NOTE ABOUT CALLBACKS AND THREADS
    //
    // All speech synthesis callbacks, except for the Text Done callback, call their specified routine on a
    // thread other than the main thread.  Performing certain actions directly from a speech synthesis callback
    // routine may cause your program to crash without certain safe gaurds.	 In this example, we use the NSThread
    // method performSelectorOnMainThread:withObject:waitUntilDone: to safely update the user interface and
    // interact with our objects using only the main thread.
    //
    // Depending on your needs you may be able to specify your Cocoa application is multiple threaded
    // then preform actions directly from the speech synthesis callback routines.  To indicate your Cocoa
    // application is mulitthreaded, call the following line before calling speech synthesis routines for
    // the first time:
    //
    // [NSThread detachNewThreadSelector:@selector(self) toTarget:self withObject:nil];
    //
    
    /*----------------------------------------------------------------------------------------
    OurErrorCFCallBackProc
    
    Called by speech channel when an error occurs during processing of text to speak.
    ----------------------------------------------------------------------------------------*/
    func speechSynthesizer(sender: NSSpeechSynthesizer, didEncounterErrorAtIndex characterIndex: Int, ofString string: String, message: String) {
        autoreleasepool {
            if self.shouldDisplayErrorCallbacks {
                dispatch_async(dispatch_get_main_queue()) {
                    let alert = NSAlert()
                    alert.messageText = message
                    alert.runModal()
                }
            }
        }
    }
    
    /*----------------------------------------------------------------------------------------
    OurSpeechDoneCallBackProc
    
    Called by speech channel when all speech has been generated.
    ----------------------------------------------------------------------------------------*/
    func speechSynthesizer(sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        autoreleasepool {
            dispatch_async(dispatch_get_main_queue()) {
                self.speechIsDone()
            }
        }
    }
    
    /*----------------------------------------------------------------------------------------
    OurSyncCallBackProc
    
    Called by speech channel when it encouters a synchronization command within an
    embedded speech comand in text being processed.
    ----------------------------------------------------------------------------------------*/
    func speechSynthesizer(sender: NSSpeechSynthesizer, didEncounterSyncMessage message: String) {
        autoreleasepool {
            if self.shouldDisplaySyncCallbacks {
                dispatch_async(dispatch_get_main_queue()) {
                    self.displaySyncAlertWithMessage(message)
                }
            }
        }
    }
    
    /*----------------------------------------------------------------------------------------
    OurPhonemeCallBackProc
    
    Called by speech channel every time a phoneme is about to be generated.	 You might use
    this to animate a speaking character.
    ----------------------------------------------------------------------------------------*/
    func speechSynthesizer(sender: NSSpeechSynthesizer, willSpeakPhoneme phonemeOpcode: Int16) {
        autoreleasepool {
            if self.shouldDisplayPhonemeCallbacks {
                dispatch_async(dispatch_get_main_queue()) {
                    self.characterView.setExpressionForPhoneme(Int(phonemeOpcode))
                }
            }
        }
    }
    
    /*----------------------------------------------------------------------------------------
    OurWordCallBackProc
    
    Called by speech channel every time a word is about to be generated.  This program
    uses this callback to highlight the currently spoken word.
    ----------------------------------------------------------------------------------------*/
    func speechSynthesizer(sender: NSSpeechSynthesizer, willSpeakWord characterRange: NSRange, ofString string: String) {
        autoreleasepool {
            if self.shouldDisplayWordCallbacks {
                dispatch_async(dispatch_get_main_queue()) {
                    self.highlightWordWithRange(characterRange)
                }
            }
        }
    }
}

///*----------------------------------------------------------------------------------------
//OurTextDoneCallBackProc
//
//Called by speech channel when all text has been processed.	Additional text can be
//passed back to continue processing.
//----------------------------------------------------------------------------------------*/
//private func OurTextDoneCallBackProc(inSpeechChannel: SpeechChannel,
//    _ inRefCon: SRefCon,
//    _ inNextBuf: UnsafeMutablePointer<UnsafePointer<Void>>,
//    _ inByteLen: UnsafePointer<UInt>,
//    _ inControlFlags: UnsafePointer<Int>)
//{
//    autoreleasepool {
//        let stw = unsafeBitCast(inRefCon, SpeakingTextWindow.self)
//        inNextBuf.memory = nil
//        if stw.shouldDisplayTextDoneCallbacks {
//            dispatch_async(dispatch_get_main_queue()) {
//                stw.displayTextDoneAlert()
//            }
//        }
//    }
//}
