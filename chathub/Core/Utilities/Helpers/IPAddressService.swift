

import Foundation
import FirebaseCore
import FirebaseFirestore

class IPAddressService {

	func getIPAddress() {
		AppLogger.log(tag: "LOG-APP: IPAddressService", message: "getIPAddress()")

		guard let url = URL(string: "https://api.ipify.org") else {
			AppLogger.log(tag: "LOG-APP: IPAddressService", message: "getIPAddress(): Invalid URL for IP service")
			return
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"

		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			if let error = error {
				AppLogger.log(tag: "LOG-APP: IPAddressService", message: "getIPAddress(): network error: \(error.localizedDescription)")
				return
			}
			guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
				AppLogger.log(tag: "LOG-APP: IPAddressService", message: "getIPAddress(): response data is nil or invalid encoding")
				return
			}
			AppLogger.log(tag: "LOG-APP: IPAddressService", message: "getIPAddress(): successfully retrieved IP: \(responseString)")
			self.getIpDetails(ipAddress: responseString)
		}
		task.resume()
	}

	func getIpDetails( ipAddress: String) {
		AppLogger.log(tag: "LOG-APP: IPAddressService", message: "getIpDetails()")

		guard let url = URL(string: "https://www.geoplugin.net/json.gp?ip=\(ipAddress)") else {
			AppLogger.log(tag: "LOG-APP: IPAddressService", message: "getIpDetails(): Invalid URL for IP details service with IP: \(ipAddress)")
			return
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"

		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			if let error = error {
				AppLogger.log(tag: "LOG-APP: IPAddressService", message: "getIpDetails(): network error: \(error.localizedDescription)")
				return
			}
			guard let data = data else {
				AppLogger.log(tag: "LOG-APP: IPAddressService", message: "getIpDetails(): response data is nil")
				return
			}
			do {
				if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
					AppLogger.log(tag: "LOG-APP: IPAddressService", message: "getIpDetails(): successfully parsed JSON response")

					SessionManager.shared.userRetrievedIp = json["geoplugin_request"] as? String ?? ""
					SessionManager.shared.userRetrievedCity = json["geoplugin_city"] as? String ?? ""
					SessionManager.shared.userRetrievedState = json["geoplugin_region"] as? String ?? ""
					SessionManager.shared.userRetrievedCountry = json["geoplugin_countryName"] as? String ?? ""

					self.saveIpDetailsOnFirebase()
				}
			} catch {
				AppLogger.log(tag: "LOG-APP: IPAddressService", message: "getIpDetails(): JSON parsing error: \(error.localizedDescription)")
			}
		}
		task.resume()
	}

	func saveIpDetailsOnFirebase() {
		AppLogger.log(tag: "LOG-APP: IPAddressService", message: "saveIpDetailsOnFirebase()")

		let dataUpdate: [String: Any] = [
			"userRetrievedIp": SessionManager.shared.userRetrievedIp ?? "",
			"userRetrievedCity": SessionManager.shared.userRetrievedCity ?? "",
			"userRetrievedState": SessionManager.shared.userRetrievedState ?? "",
			"userRetrievedCountry": SessionManager.shared.userRetrievedCountry ?? ""
		]

		Firestore.firestore()
			.collection("Users")
			.document(SessionManager.shared.userId ?? "unknown_user")
			.setData(dataUpdate, merge: true) { error in
				if let error = error {
					AppLogger.log(tag: "LOG-APP: IPAddressService", message: "saveIpDetailsOnFirebase(): Firebase save error: \(error.localizedDescription)")
				} else {
					AppLogger.log(tag: "LOG-APP: IPAddressService", message: "saveIpDetailsOnFirebase(): successfully saved IP details to Firebase")
				}
			}
	}
}

