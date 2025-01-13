 export const MfaView = () => {
  const [userDevices, setUserDevices] = useState<MFADevice[]>([]);
  const [mfaRegisterData, setMfaRegisterData] = useState<MfaRegisterData>();
  const [currentView, setCurrentView] = useState<string>("devices");
  const [backupCodes, setBackupCodes] = useState<string[]>([]);
  const [error, setError] = useState<string>();

  const isLogged = useIsLoggedIn();
  const {
    addDevice,
    authDevice,
    getUserDevices,
    getRecoveryCodes,
    completeAcknowledgement,
  } = useMfa();

  const refreshUserDevices = async () => {
    const devices = await getUserDevices();
    setUserDevices(devices);
  };

  const { userWithMissingInfo, handleLogOut } = useDynamicContext();
  useEffect(() => {
    if (isLogged) {
      refreshUserDevices();
    }
  }, [isLogged]);

  useSyncMfaFlow({
    handler: async () => {
      if (userWithMissingInfo?.scope?.includes("requiresAdditionalAuth")) {
        getUserDevices().then(async (devices) => {
          if (devices.length === 0) {
            setError(undefined);
            const { uri, secret } = await addDevice();
            setMfaRegisterData({ secret, uri });
            setCurrentView("qr-code");
          } else {
            setError(undefined);
            setMfaRegisterData(undefined);
            setCurrentView("otp");
          }
        });
      } else {
        getRecoveryCodes().then(setBackupCodes);
        setCurrentView("backup-codes");
      }
    },
  });

  const onAddDevice = async () => {
    setError(undefined);
    const { uri, secret } = await addDevice();
    setMfaRegisterData({ secret, uri });
    setCurrentView("qr-code");
  };

  const onQRCodeContinue = async () => {
    setError(undefined);
    setMfaRegisterData(undefined);
    setCurrentView("otp");
  };

  const onOtpSubmit = async (code: string) => {
    try {
      await authDevice(code);
      getRecoveryCodes().then(setBackupCodes);
      setCurrentView("backup-codes");
      refreshUserDevices();
    } catch (e) {
      setError(e.message);
    }
  };

  return (
    <div className="headless-mfa">
      <DynamicWidget />
      <button onClick={handleLogOut}>log out</button>
      {error && <div className="headless-mfa__section error">{error}</div>}
      {currentView === "devices" && (
        <div className="headless-mfa__section">
          <p>
            <b>Devices</b>
          </p>
          <pre>{JSON.stringify(userDevices, null, 2)}</pre>
          <button onClick={() => onAddDevice()}>Add Device</button>
        </div>
      )}
      {currentView === "qr-code" && mfaRegisterData && (
        <QRCodeView data={mfaRegisterData} onContinue={onQRCodeContinue} />
      )}
      {currentView === "otp" && <OTPView onSubmit={onOtpSubmit} />}
      {currentView === "backup-codes" && (
        <BackupCodesView
          codes={backupCodes}
          onAccept={completeAcknowledgement}
        />
      )}
      <button
        onClick={async () => {
          const codes = await getRecoveryCodes(true);
          setBackupCodes(codes);
          setCurrentView("backup-codes");
        }}
      >
        Generate Recovery Codes
      </button>
    </div>
  );
};
