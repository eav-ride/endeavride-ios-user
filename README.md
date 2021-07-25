# endeavride-ios-user

## Installation

1. Clone this git repository
2. Navigate to this repository, run `pod install` to install all required dependencies using CocoaPods
3. Open ENDEAVRide.xcworkspace to open the project, now you can try to run on simulator
4. If you want to running on a device, click ENDEAVRide from the left pannel of XCode, choose TARGETS as ENDEAVRide, in Signings & Capabilities, set up the developmenmt team by loging with Apple developer account, and follow the instructions
5. Default server address is pointing at AWS EC2, if you want to point to a local server, go to Utils.swift file, and follow the comments to set up the base URL
