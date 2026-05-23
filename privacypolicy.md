Last updated: May 23, 2026

AI Calorie Coach is developed by Faizan Shaikh, an independent developer.

This policy explains what information the app collects, stores, syncs, and shares when you use AI Calorie Coach.

---

## 1. Information We Collect

### a) Account Information

AI Calorie Coach requires sign-in so your data can be synced and restored across devices.

When you sign in with Apple or Google, we may receive and store:

- Your account provider, such as Apple or Google
- Your provider account identifier
- Your email address, if provided by the sign-in provider
- Your name, if provided
- Your profile photo URL, if provided
- Internal user ID, creation date, and update date

We use this information only to authenticate your account and sync your app data.

### b) Food Photos

When you use the camera or photo library feature:

- The image is resized and compressed on your device.
- The compressed image may be sent to OpenAI to estimate the nutritional content of the food.
- If you save the meal, the meal photo may also be uploaded to our server so it can sync across your signed-in devices.
- Uploaded photos are stored outside the public web root and are accessible only through authenticated app requests.
- Uploaded photos are associated with your account and meal record.

### c) Meal and Nutrition Data

We store meal data locally on your device and sync it to our server when you are signed in.

This may include:

- Meal date and meal type
- Estimated calories
- Macronutrients and other nutrition values
- Food item names and portion estimates
- AI-generated assumptions
- Associated meal photo reference
- Created, updated, and deleted status information used for syncing

### d) Saved Foods

User-created saved foods, including foods added manually or generated from AI results, may be stored locally and synced to our server.

Bundled/default food database items included with the app are local app content and are not uploaded as your personal data.

### e) App Settings

We may sync app settings needed to keep your experience consistent across devices, such as:

- Daily calorie goal
- Calorie range display preference
- Onboarding completion state

### f) Authentication and Security Data

To keep your account signed in and protect the service, we store:

- Access tokens and refresh tokens on your device using iOS Keychain
- Hashed refresh tokens on our server
- Login rate-limit records, which may include IP address and attempt count
- Basic server request information needed for security, debugging, abuse prevention, and service operation

### g) AI Requests, Proxy Identifiers, and OpenAI API Key

If you add your own OpenAI API key, it is stored only in the iOS Keychain on your device.

Your OpenAI API key is not uploaded to our server. It is sent directly to OpenAI only when making authenticated OpenAI API requests from your device.

If you do not add your own OpenAI API key, the app may use our built-in proxy service for AI analysis and AI-powered food search. In that case, your food image, food search text, and analysis request may pass through our proxy before being sent to OpenAI. The proxy may receive technical identifiers such as bundle ID, device identifier, IP address, and request metadata for rate limiting, abuse prevention, debugging, and service operation.

### h) Analytics and App Usage Data

The app includes Firebase Analytics. Firebase Analytics may automatically collect technical and usage information such as:

- App launches, sessions, screen or feature interactions, and other app events
- App version, device model, operating system version, language, region, and similar device or app information
- App instance identifiers or similar analytics identifiers used by Firebase/Google to measure app usage

We use analytics to understand app reliability, usage, and feature performance. We do not use analytics data for third-party advertising, and we do not use analytics to sell personal information.

---

## 2. How We Use Your Information

We use your information to:

- Create and authenticate your account
- Sync your meals, saved foods, photos, and settings across devices
- Restore your data after reinstalling the app or signing in on another device
- Estimate nutrition from food photos using AI
- Provide app functionality such as history, dashboard, saved foods, and settings
- Understand app usage, reliability, and feature performance using analytics
- Prevent abuse, enforce rate limits, debug issues, and maintain service security
- Delete your account and associated data when requested

We do not sell your personal data.

---

## 3. Data Sharing and Third Parties

We share data only as needed to provide app functionality.

### OpenAI

Food photos and prompts may be sent to OpenAI for AI-powered nutrition analysis.

If you use your own OpenAI API key, requests are sent directly from your device to OpenAI.

If you use the built-in service, requests may pass through our proxy before being sent to OpenAI.

OpenAI's handling of API data is governed by OpenAI's policies:
https://openai.com/policies/privacy-policy

### Apple

If you sign in with Apple, Apple provides authentication services and may share account information such as your Apple account identifier and, if you allow it, your email or relay email.

### Google

If you sign in with Google, Google provides authentication services and may share account information such as your Google account identifier, email, name, and profile photo URL.

### Firebase / Google Services

The app includes Firebase/Google configuration used for app services such as Google Sign-In and Firebase Analytics. These services may process sign-in information, technical information, app instance identifiers, device/app information, and usage events according to Google's policies.

Google privacy policy:
https://policies.google.com/privacy

---

## 4. Information We Do Not Collect for Advertising

We do not collect data for third-party advertising.

We do not sell personal information.

We do not use your meal photos, meal logs, saved foods, or nutrition data for advertising.

---

## 5. Data Storage and Retention

Your data is stored in two places:

- Locally on your device
- On our server, when you are signed in

Server-stored data may include your account profile, meal records, food items, saved foods, settings, and meal photos.

Meal photos are stored in a private server upload directory outside the public web root and are served only through authenticated app requests.

Deleted meals and saved foods may be temporarily retained as sync deletion records so changes can propagate across devices. They are removed or hidden according to the app's sync and cleanup behavior.

Authentication and security records may be retained as needed to keep your account signed in, prevent abuse, and operate the service.

Firebase Analytics data is retained and processed according to Firebase/Google settings and policies. It may not be removed by deleting your AI Calorie Coach account unless Firebase/Google provides a separate deletion mechanism or the data is no longer identifiable.

---

## 6. Deleting Your Data

You can delete data in the app:

- To delete meal data from the app, use the app's data deletion controls.
- To remove your OpenAI API key, go to Settings and remove the key.
- To sign out, use the account section in Settings.
- To permanently delete your account, use Delete Account in Settings.

Deleting your account removes your account data from our server, including meal history, saved foods, settings, refresh tokens, and uploaded meal photos associated with your account.

Deleting your account does not automatically delete data already processed by third-party providers such as OpenAI, Apple, Google, or Firebase. Those providers handle data according to their own policies.

Deleting the app from your device removes local app data from that device, but it does not automatically delete server data. To remove server data, use Delete Account before uninstalling or contact us.

---

## 7. Security

We use reasonable technical safeguards to protect your data, including:

- HTTPS/TLS for network communication
- iOS Keychain for access tokens, refresh tokens, and optional OpenAI API key
- Authenticated API requests for account data and photos
- Hashed refresh tokens stored on the server
- Server-side access checks so users can access only their own data
- Meal photo storage outside the public web root

No system is completely secure, but we take reasonable steps to protect your information.

---

## 8. Children's Privacy

AI Calorie Coach is not intended to knowingly collect personal information from children without appropriate consent.

If you believe a child has provided personal information through the app, contact us and we will take appropriate steps to delete it.

---

## 9. Your Rights

Depending on where you live, you may have rights to access, correct, export, or delete your personal data.

You can delete your account in the app. You may also contact us for privacy-related requests.

If your request concerns data handled by OpenAI, Apple, Google, or Firebase, you may also need to contact those providers directly.

---

## 10. Changes to This Policy

We may update this policy when the app changes or when legal, operational, or security requirements change.

If we make material changes, we will update the "Last updated" date at the top of this page.

---

## 11. Contact

If you have questions about this privacy policy or want to request help with your data, contact:

mfaizan.shaikh@gmail.com
