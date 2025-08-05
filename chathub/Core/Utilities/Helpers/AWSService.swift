

import Foundation
import AWSCore
import AWSS3
import AWSCognito
import AWSSNS
import AWSSES

class AWSService {

	static let sharedInstance = AWSService()

	var aws_cognito_identity_pool_id_for_photo_upload: String = ""
	var aws_ses_send_email_id: String = ""

	private init() {
		AppLogger.log(tag: "LOG-APP: AWSService", message: "init()")
		getCredentials()
		logIntoAWS()
	}

	func getCredentials(){
		AppLogger.log(tag: "LOG-APP: AWSService", message: "getCredentials()")

		guard let path = Bundle.main.path(forResource: "SecureKeyValuePlist", ofType: "plist"),
			  let xml = FileManager.default.contents(atPath: path),
			  let plist = try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
			AppLogger.log(tag: "LOG-APP: AWSService", message: " getCredentials(): Unable to load SecureKeyValuePlist file - using default configuration")
			
			// CRITICAL FIX: Instead of fatalError, use default/empty configuration and continue
			// This prevents binary corruption from app crashes during launch
			aws_cognito_identity_pool_id_for_photo_upload = ""
			aws_ses_send_email_id = ""
			return
		}

		aws_cognito_identity_pool_id_for_photo_upload = plist["aws_cognito_identity_pool_id_for_photo_upload"] as? String ?? ""
		aws_ses_send_email_id = plist["aws_ses_send_email_id"] as? String ?? ""
		
		// CRITICAL FIX: Log loaded credentials for validation debugging
		AppLogger.log(tag: "LOG-APP: AWSService", message: " getCredentials(): Successfully loaded AWS credentials - CognitoID: '\(aws_cognito_identity_pool_id_for_photo_upload.isEmpty ? "empty" : "loaded")', SESID: '\(aws_ses_send_email_id.isEmpty ? "empty" : "loaded")')")
	}

	func logIntoAWS(){
		AppLogger.log(tag: "LOG-APP: AWSService", message: " logIntoAWS()")

		// Check if credentials are available
		guard !aws_cognito_identity_pool_id_for_photo_upload.isEmpty else {
			AppLogger.log(tag: "LOG-APP: AWSService", message: " logIntoAWS(): WARNING - Cognito identity pool ID is empty")
			return
		}

		let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast1, identityPoolId: aws_cognito_identity_pool_id_for_photo_upload)
		let configuration = AWSServiceConfiguration(region:.USEast1, credentialsProvider:credentialsProvider)
		AWSServiceManager.default().defaultServiceConfiguration = configuration

	}



	func uploadImageToS3(image: UIImage, imageName: String, completionHandler: @escaping (String?, Error?) -> Void) {
		AppLogger.log(tag: "LOG-APP: AWSService", message: " uploadImageToS3()")

		let userId = UserSessionManager.shared.userId ?? ""
		let bucketName = "strangerchatuser"
		let key = "user/\(userId)/\(imageName)"

		AppLogger.log(tag: "LOG-APP: AWSService", message: " uploadImageToS3(): bucketName=\(bucketName), key=\(key)")

		guard let imageData = image.jpegData(compressionQuality: 0.5) else {
			AppLogger.log(tag: "LOG-APP: AWSService", message: " uploadImageToS3(): image.jpegData(compressionQuality: 0.5) failed")
			completionHandler(nil, NSError(domain: "UploadImageToAwsClass", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to convert image to data"]))
			return
		}

		let expression = AWSS3TransferUtilityUploadExpression()
		expression.progressBlock = { (task, progress) in
			DispatchQueue.main.async {
				AppLogger.log(tag: "LOG-APP: AWSService", message: " uploadImageToS3(): Upload Progress: \(progress.fractionCompleted)")
			}
		}
		expression.setValue("public-read", forRequestHeader: "x-amz-acl")

		let transferUtility = AWSS3TransferUtility.default()
		transferUtility.uploadData(imageData,
								   bucket: bucketName,
								   key: key,
								   contentType: "image/jpeg",
								   expression: expression) { (task, error) -> Void in
			DispatchQueue.main.async {
				if let error = error {
					completionHandler(nil, error)
					AppLogger.log(tag: "LOG-APP: AWSService", message: " uploadImageToS3(): Upload Progress: \(error)")
				} else {
					let imageUrl = "https://\(bucketName).s3.amazonaws.com/user/\(userId)/\(imageName)"
					completionHandler(imageUrl, nil)
					AppLogger.log(tag: "LOG-APP: AWSService", message: " uploadImageToS3(): Upload Progress: \(imageUrl)")
				}
			}
		}
	}


	func deleteImageFromS3(imageName: String, completion: @escaping (Error?) -> Void) {
		AppLogger.log(tag: "LOG-APP: AWSService", message: " deleteImageFromS3()")

		let userId = UserSessionManager.shared.userId ?? ""
		let bucketName = "strangerchatuser"
		let key = "user/\(userId)/\(imageName)"

		guard let deleteRequest = AWSS3DeleteObjectRequest() else {
			AppLogger.log(tag: "LOG-APP: AWSService", message: " deleteImageFromS3(): Failed to create delete request")
			completion(NSError(domain: "AWSService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create delete request"]))
			return
		}
		
		deleteRequest.bucket = bucketName
		deleteRequest.key = key

		let s3 = AWSS3.default()
		s3.deleteObject(deleteRequest).continueWith { (task) -> AnyObject? in
			DispatchQueue.main.async {
				if let error = task.error {
					AppLogger.log(tag: "LOG-APP: AWSService", message: " deleteImageFromS3(): Error: \(error.localizedDescription)")
					completion(error)
				} else {
					AppLogger.log(tag: "LOG-APP: AWSService", message: " deleteImageFromS3(): Successfully deleted image")
					completion(nil)
				}
			}
			return nil
		}
	}


	func sendOTPEmail(email: String, otp: String, completion: @escaping (Error?) -> Void) {
		AppLogger.log(tag: "LOG-APP: AWSService", message: " sendOTPEmail()")

		let sesClient = AWSSES.default()

		let fromEmail = self.aws_ses_send_email_id

		let subject = AWSSESContent()
		subject?.data = "ChatHub iOS Email Verification - Do Not Reply"

		let bodyText = AWSSESContent()
		bodyText?.data = "Your OTP for email verification - \(otp)"

		let body = AWSSESBody()
		body?.text = bodyText

		let message = AWSSESMessage()
		message?.subject = subject
		message?.body = body

		let sendEmailRequest = AWSSESSendEmailRequest()
		sendEmailRequest?.destination = AWSSESDestination()
		sendEmailRequest?.destination?.toAddresses = [email]
		sendEmailRequest?.message = message
		sendEmailRequest?.source = fromEmail

		sesClient.sendEmail(sendEmailRequest!).continueWith { (task: AWSTask) -> Any? in
			if let error = task.error {
				AppLogger.log(tag: "LOG-APP: AWSService", message: " sendOTPEmail(): Error sending email: \(error.localizedDescription)")
				completion(error)
			} else {
				AppLogger.log(tag: "LOG-APP: AWSService", message: " sendOTPEmail(): Email sent successfully")
				completion(nil)
			}
			return nil
		}
	}

}
