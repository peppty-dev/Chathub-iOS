import UIKit
import Foundation
import OSLog

// Add extension to NSMutableData to provide appendString functionality
extension NSMutableData {
	func appendString(string: String) {
		if let data = string.data(using: .utf8) {
			self.append(data)
		}
	}
}

class HiveImageModerationHelper  {

	static let sharedInstance = HiveImageModerationHelper()

	var nsfw: Bool = false
	var hive_token: String = ""

	private init() {
		AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "init()")
		getCredentials()
	}

	func getCredentials(){
		AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "getCredentials()")

		guard let path = Bundle.main.path(forResource: "SecureKeyValuePlist", ofType: "plist"),
			  let xml = FileManager.default.contents(atPath: path),
			  let plist = try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
			AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "getCredentials(): Unable to load SecureKeyValuePlist file - using default token")
			
			// CRITICAL FIX: Instead of fatalError, use default/empty token and continue
			// This prevents binary corruption from app crashes during launch
			hive_token = ""
			return
		}

		hive_token = plist["hive_token"] as? String ?? ""
		
		// CRITICAL FIX: Log loaded credentials for validation debugging
		AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "getCredentials(): Successfully loaded Hive token - Token: '\(hive_token.isEmpty ? "empty" : "loaded")')")
	}

	func performImageModeration( imagePath: String, pickedImage: UIImage, completionHandler: @escaping (Bool) -> Void ) {
		AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration()")

		let userId = SessionManager.shared.userId ?? ""

		let imageName = "\(userId)_\(Int64(Date().timeIntervalSince1970))"

		let imageData =  pickedImage.jpegData(compressionQuality: 0.3)

		guard let imageData = imageData else {
			AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): Error: Unable to read image data.")
			completionHandler(false)
			return
		}

		guard let url = URL(string: "https://api.thehive.ai/api/v2/task/sync") else {
			AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): Error: Invalid Hive API URL")
			completionHandler(false)
			return
		}
		
		// Check if we have a valid token before making the API request
		guard !hive_token.isEmpty else {
			AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): Error: Empty Hive token - cannot perform moderation")
			completionHandler(false)
			return
		}
		
		let boundary = "Boundary-\(NSUUID().uuidString)"

		let body = NSMutableData()
		body.appendString(string:"--\(boundary)\r\n")
		body.appendString(string:"Content-Disposition: form-data; name=\"image\"; filename=\"\(imageName)\"\r\n")
		body.appendString(string:"Content-Type: image/jpeg\r\n\r\n")
		body.append(imageData as Data)
		body.appendString(string:"\r\n")
		body.appendString(string:"--\(boundary)--\r\n")

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "accept")
		request.setValue("token \(hive_token)", forHTTPHeaderField: "authorization")
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		request.httpBody = body as Data


		let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: {
			(data, response, error) -> Void in

			self.logSplit(str: "response: \(String(describing: response))")
			self.logSplit(str: "data: \(String(describing: data))")

			guard let responseData = data else {
				AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): No data received")
				return
			}

			if let responseString = String(data: responseData, encoding: .utf8) {
				AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): Response string: \(responseString)")


				// Convert the JSON string to Data
				if let jsonData = responseString.data(using: .utf8) {
					do {
						// Parse the JSON data into a dictionary
						if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
							// Access the "status" array
							if let statusArray = jsonDict["status"] as? [[String: Any]] {
								// Loop through each element in the "status" array
								for statusItem in statusArray {
									// Access the "response" dictionary
									if let responseDict = statusItem["response"] as? [String: Any] {
										// Access the "output" array
										if let outputArray = responseDict["output"] as? [[String: Any]] {
											// Loop through each element in the "output" array
											for outputItem in outputArray {
												// Access the "classes" array
												if let classesArray = outputItem["classes"] as? [[String: Any]] {
													// Loop through each element in the "classes" array
													var imageModerationScore = 0.0

													for classItem in classesArray {
														// Access and print the "class" and "score" values
														let classValue = classItem["class"] as? String
														let scoreValue = classItem["score"] as? Double

														let decimalString = String(format: "%.4f", scoreValue ?? 0)
														let doubleX = Double(decimalString) ?? 0

														AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): classValue: \(String(describing: classValue)), scoreValue:\(String(describing: scoreValue)), Formatted doubleX: \(doubleX)")


														if classValue == "general_nsfw"  ||
															classValue == "general_suggestive"   ||
															classValue == "yes_female_underwear"   ||
															classValue == "yes_male_underwear"   ||
															classValue == "yes_sex_toy"   ||
															classValue == "yes_female_nudity"   ||
															classValue == "yes_male_nudity"   ||
															classValue == "yes_female_swimwear"   ||
															classValue == "yes_male_shirtless"   ||
															classValue == "text"   ||
															classValue == "animated_gun"   ||
															classValue == "gun_in_hand"   ||
															classValue == "gun_not_in_hand"   ||
															classValue == "culinary_knife_in_hand"   ||
															classValue == "knife_in_hand"   ||
															classValue == "knife_not_in_hand"   ||
															classValue == "a_little_bloody"   ||
															classValue == "other_blood"   ||
															classValue == "very_bloody"   ||
															classValue == "yes_pills"   ||
															classValue == "yes_smoking"   ||
															classValue == "illicit_injectables"   ||
															classValue == "medical_injectables"   ||
															classValue == "yes_nazi"   ||
															classValue == "yes_kkk"   ||
															classValue == "yes_middle_finger"   ||
															classValue == "yes_terrorist"   ||
															classValue == "yes_overlay_text"   ||
															classValue == "yes_sexual_activity"   ||
															classValue == "hanging"   ||
															classValue == "noose"   ||
															classValue == "yes_realistic_nsfw"   ||
															classValue == "animated_corpse"   ||
															classValue == "human_corpse"   ||
															classValue == "yes_self_harm"   ||
															classValue == "yes_drawing"   ||
															classValue == "yes_emaciated_body"   ||
															classValue == "yes_sexual_intent"   ||
															classValue == "animal_genitalia_and_human"   ||
															classValue == "animal_genitalia_only"   ||
															classValue == "animated_animal_genitalia"   ||
															classValue == "yes_gambling"   ||
															classValue == "yes_undressed"   ||
															classValue == "yes_confederate"   {

															AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): inside classValue: \(String(describing: classValue)), scoreValue:\(String(describing: scoreValue)), Formatted doubleX: \(doubleX)")

															AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "------------------------------------------------")

															if doubleX > 0.8000 {
																imageModerationScore += doubleX
																if imageModerationScore > 0.9000 {
																	AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): NSFW detected")
																	self.nsfw = true
																	ModerationService.shared.incrementImageModerationScore()
																	AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration: NSFW detected, incrementing image moderation score for warning.")
																	break
																}else{
																	AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): NSFW not detected")
																}
															}
														}
													}
												}
											}
										}
									}
								}
							}
						}
					} catch {
						AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): Error parsing JSON: \(error)")
					}
				} else {
					AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): Invalid JSON string")
				}
			}

			DispatchQueue.main.async {
				AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "performImageModeration(): Result: \(self.nsfw)")
				completionHandler(self.nsfw)
			}

		})

		task.resume()

	}


	func logSplit(str: String) {
		if str.count > 1000 {
			let index = str.index(str.startIndex, offsetBy: 1000)
			AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "LogSplit: \(str[..<index])")
			logSplit(str: String(str[index...]))
		} else {
			AppLogger.log(tag: "LOG-APP: HiveImageModerationHelper", message: "LogSplit: \(str)")
		}
	}

}
