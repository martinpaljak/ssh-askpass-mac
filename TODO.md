# TODO

## Save to the Passwords app

"Save in keychain" writes an internet password (`ssh://host`, account `user`) to the
login keychain. The Passwords app and Password AutoFill don't show the login keychain;
they use the data protection keychain. Writing there fails with `-34018` ("A required
entitlement is not present") because a Developer ID app gets `application-identifier`
and `keychain-access-groups` only from an embedded provisioning profile.

1. Register the App ID `com.hardssh.ssh-askpass-mac` for team `727L5NLWT4`.
2. Create a Developer ID provisioning profile for it. Xcode can do 1 and 2 by itself
   with `-allowProvisioningUpdates` and the Apple account signed in under Xcode >
   Settings > Accounts.
3. Entitlement `keychain-access-groups = [727L5NLWT4.com.hardssh.ssh-askpass-mac]`,
   profile embedded as `Contents/embedded.provisionprofile` by `make`.
4. Save with `kSecUseDataProtectionKeychain`; check that the entry shows in Passwords
   and that AutoFill offers it in the dialog.
5. Builds without the profile (`TEAMID=-`, other teams) keep the login keychain.
