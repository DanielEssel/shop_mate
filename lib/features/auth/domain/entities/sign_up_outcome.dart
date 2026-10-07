/// What happened after a successful sign-up request.
enum SignUpOutcome {
  /// The account was created and is signed in now.
  signedIn,

  /// The account must confirm its email address before it can sign in.
  emailConfirmationRequired,
}
