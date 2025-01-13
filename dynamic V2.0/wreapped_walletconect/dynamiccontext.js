 const {locale} = useDynamicContext();

 const handleOnClick = (localeProvided) => {
    if (localeProvided === 'it') {
      locale.changeLanguage('it');
    } else {
      locale.changeLanguage('en');
    }
 };

return (
  <button onClick={() => handleOnClick(locale.language)}>
    {locale.language === 'it' ? 'English' : 'Italiano'}
  </button>
);
