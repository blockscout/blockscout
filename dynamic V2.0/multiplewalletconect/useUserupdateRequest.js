 import { useUserUpdateRequest, useOtpVerificationRequest } from "@dynamic-labs/sdk-react-core";

const { verifyOtp } = useOtpVerificationRequest();
const { updateUser } = useUserUpdateRequest();

const [showUpdateForm, setShowUpdateForm] = useState(false);
const [showVerifyForm, setShowVerifyEmailForm] = useState(false);

const updateUserInfoFormSubmit = async (e) => {
   e.preventDefault();
   try {
     setLoading(true);
     // Call the updateUser function with the new values entered by the user
     const { isEmailVerificationRequired } = await updateUser({
       firstName: e.target[0].value,
       email: e.target[1].value,
     });
     // If email verification is required, show the email verification form
     if (isEmailVerificationRequired) {
       setShowVerifyEmailForm(true);
     }
   } catch (e) {
     console.log("Error", e);
   } finally {
     setLoading(false);
     setShowUpdateForm(false);
   }
 };

   // Handler for the email verification form submission
const onVerifyEmailFormSubmit = async (e) => {
    e.preventDefault();
    try {
      setLoading(true);
      const verificationToken = e.target[0].value;
      // Call the verifyEmail function with the entered verification token
      await verifyOtp(verificationToken);
    } catch (e) {
      console.log("Error", e);
    } finally {
      setLoading(false);
      // Hide the email verification form after the process is completed
      setShowVerifyEmailForm(false);
    }
    return false;
};


return (
    <div>
          {/* Render the profile update form */}
          {showUpdateForm && (
            <div>
              <form onSubmit={onProfileFormSubmit} className="form">
                <div className="form__row">
                  <label className="label" htmlFor="firstName">
                    First-Name
                  </label>
                  <input
                    id="firstName"
                    className="form__input"
                    defaultValue={user.firstName}
                    disabled={loading || showVerifyEmailForm}
                  />
                </div>
                <div className="form__row">
                  <label className="label" htmlFor="email">
                    E-Mail
                  </label>
                  <input
                    type="email"
                    id="email"
                    className="form__input"
                    defaultValue={user.email}
                    disabled={loading || showVerifyEmailForm}
                  />
                </div>
                <button
                  disabled={loading || showVerifyEmailForm}
                  className="form__button"
                  type="submit"
                >
                  Save
                </button>
              </form>
            </div>
          )}

         {/* Render the email verification form if needed */}
          {showVerifyEmailForm && (
            <form onSubmit={onVerifyEmailFormSubmit} className="form">
              <h6>Verify Email</h6>
              <div className="form__row">
                <label htmlFor="verificationToken">Verification Token</label>
                <input
                  disabled={loading}
                  pattern="^\d{6}$"
                  name="verificationToken"
                />
              </div>
              <button disabled={loading} className="form__button" type="submit">
                Send
              </button>
            </form>
          )}
    <div>
)
