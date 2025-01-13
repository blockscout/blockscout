 const BackupCodesView = ({
  codes,
  onAccept,
}: {
  codes: string[];
  onAccept: () => void;
}) => (
  <>
    <p>Backup Codes</p>
    {codes.map((code) => (
      <p key={code}>{code}</p>
    ))}
    <button onClick={onAccept}>Accept</button>
  </>
);

const LogIn = () => (
  <>
    <p>User not logged in!</p>
    <DynamicWidget />
  </>
);

const QRCodeView = ({
  data,
  onContinue,
}: {
  data: MfaRegisterData;
  onContinue: () => void;
}) => {
  const canvasRef = useRef(null);

  useEffect(() => {
    if (!canvasRef.current) {
      return;
    }
    QRCodeUtil.toCanvas(canvasRef.current, data.uri, function (error: any) {
      if (error) console.error(error);
      console.log("success!");
    });
  });

  return (
    <>
      <div style={{ width: "320px", height: "320px" }}>
        <canvas id="canvas" ref={canvasRef}></canvas>
      </div>
      <p>Secret: {data.secret}</p>
      <button onClick={onContinue}>Continue</button>
    </>
  );
};

const OTPView = ({ onSubmit }: { onSubmit: (code: string) => void }) => (
  <form
    key="sms-form"
    onSubmit={(e) => {
      e.preventDefault();
      onSubmit(e.currentTarget.otp.value);
    }}
    className="headless-mfa__form"
  >
    <div className="headless-mfa__form__section">
      <label htmlFor="otp">OTP:</label>
      <input type="text" name="otp" placeholder="123456" />
    </div>
    <button type="submit">Submit</button>
  </form>
);
