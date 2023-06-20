# OSG Classes

My Powershell Classes

These are the Powerhsell classes I have developed and use in virturally every script I write

[FlashID] Generates a unique Instance ID based on time elapsed since the Unix Epoch

The first Section is a 4 character Hexidecimal representation of the Days elapsed since 1/1/1970 The second section is a representation of the time passed in the current day. The third section is a 4 Character (Adjunct) Alpha string, which will insure that the FlashID is unique across different installations. (Adjunct string will not include and digits or characters used in Hexidecimal notation, [0-9][A-F])

[EZSettings] Retrieves and Maintains Module settings and can generate am easy reference HashTable that can be easily referenced

[Ticker] Wrapper Class for Write-Progress to easily display a progress bar

Each class contains a <ClassName>:Help() static method that will display an HTLM help file
