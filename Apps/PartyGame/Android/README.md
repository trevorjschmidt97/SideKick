# PartyGame Android Target

Android is intentionally documented as next work for this first Swift vertical
slice. The shared architecture already models Android as a supported platform in
`SideKickAppCore.PlatformRolePolicy`, where Android can host the board or join a
game.

Next Android steps:

1. Add Kotlin/Compose targets under Bazel.
2. Mirror `GameCore` value models or generate them from a shared schema.
3. Implement an Android app shell that calls the Firebase game service through
   protocol-compatible adapters.
4. Reuse the same platform role policy: Android can host or join.
