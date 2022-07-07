using Microsoft.AspNetCore.Mvc.DataAnnotations;
using Microsoft.Extensions.Localization;
using System.ComponentModel.DataAnnotations;

using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;
using System.Globalization;

namespace RecruitmentFailWeb.Models.DataAnnotations
{
    public class CognitoPasswordAttribute : ValidationAttribute
    {
        private static String _digitChar = @"\d";
        private static String _lowercaseChar = @"a-z";
        private static String _uppercaseChar = @"A-Z";
        private static String _specialChar = String.Format(
            @" \^\$\*\.\[\]\{{\}}\(\)\?\!\@\#\%\&\/\\\,\>\<\'\:\;\|_\~\`\=\+\-{0}",
            "\\\""
        );

        private static String _validChar = $"{_digitChar}{_lowercaseChar}{_uppercaseChar}{_specialChar}";

        private static Regex _requireDigitRegex = new Regex($"[{_digitChar}]", RegexOptions.Compiled);
        private static Regex _requireLowercaseRegex = new Regex($"[{_lowercaseChar}]", RegexOptions.Compiled);
        private static Regex _requireUppercaseRegex = new Regex($"[{_uppercaseChar}]", RegexOptions.Compiled);
        private static Regex _requireSpecialRegex = new Regex($"[{_specialChar}]", RegexOptions.Compiled);
        private static Regex _allValidCharRegex = new Regex($"^[{_validChar}]*$", RegexOptions.Compiled);

        private const String _digitReqMsg = "Password requires at least one digit.";
        private const String _lowercaseReqMsg = "Password requires at least one lowercase character.";
        private const String _uppercaseReqMsg = "Password requires at least one uppercase character.";
        private const String _specialReqMsg = "Password requires at least one special character.";

        private static Tuple<CharacterOptions, Regex, String>[] _charValExps = {
            new Tuple<CharacterOptions, Regex, String>(CharacterOptions.DIGIT, _requireDigitRegex, _digitReqMsg),
            new Tuple<CharacterOptions, Regex, String>(CharacterOptions.LOWER, _requireLowercaseRegex, _lowercaseReqMsg),
            new Tuple<CharacterOptions, Regex, String>(CharacterOptions.UPPER, _requireUppercaseRegex, _uppercaseReqMsg),
            new Tuple<CharacterOptions, Regex, String>(CharacterOptions.SPECIAL, _requireSpecialRegex, _specialReqMsg)
        };

        [Flags]
        public enum CharacterOptions
        {
            NONE = 0x0,
            DIGIT = 0x1,
            LOWER = 0x2,
            UPPER = 0x4,
            SPECIAL = 0x8,
            ALL = DIGIT | LOWER | UPPER | SPECIAL
        }

        public static int DEFAULT_MIN_LENGTH = 8;
        public static int DEFAULT_MAX_LENGTH = 256;

        /// <summary>
        /// bit mask of required characters
        /// </summary>
        public CharacterOptions RequiredChars { get; set; }

        /// <summary>
        /// Is at least one digit required in the password?
        /// </summary>
        public bool IsDigitRequired
        {
            get { return IsRequired(CharacterOptions.DIGIT); }
            set { SetCharRequired(CharacterOptions.DIGIT, value); }
        }

        /// <summary>
        /// Is at least one lowercase character required?
        /// </summary>
        public bool IsLowercaseRequired
        {
            get { return IsRequired(CharacterOptions.LOWER); }
            set { SetCharRequired(CharacterOptions.LOWER, value); }
        }

        /// <summary>
        /// Is at least one uppercase character required?
        /// </summary>
        public bool IsUppercaseRequired
        {
            get { return IsRequired(CharacterOptions.UPPER); }
            set { SetCharRequired(CharacterOptions.UPPER, value); }
        }

        /// <summary>
        /// Is at least one special character required?
        /// </summary>
        public bool IsSpecialRequired
        {
            get { return IsRequired(CharacterOptions.SPECIAL); }
            set { SetCharRequired(CharacterOptions.SPECIAL, value); }
        }

        /// <summary>
        /// minimum required password length
        /// </summary>
        public int MinLength { get; set; }

        /// <summary>
        /// maximum required password length
        /// </summary>
        public int MaxLength { get; set; }

        /// <summary>
        /// Constructor
        /// </summary>
        public CognitoPasswordAttribute()
        {
            RequiredChars = CharacterOptions.NONE;
            MinLength = DEFAULT_MIN_LENGTH;
            MaxLength = DEFAULT_MAX_LENGTH;
        }

        /// <summary>
        /// Check whether an individual character option is required or not.
        /// </summary>
        /// <param name="option">option</param>
        /// <returns>true if required; false otherwise</returns>
        private bool IsRequired(CharacterOptions option)
        {
            return (RequiredChars & option) == option;
        }

        /// <summary>
        /// Set a character class to be required or not required.
        /// </summary>
        /// <param name="option">option</param>
        /// <param name="value">true for required; false for not required</param>
        private void SetCharRequired(CharacterOptions option, bool value)
        {
            if (value)
            {
                RequiredChars |= option;
            }
            else
            {
                RequiredChars &= ~option;
            }
        }

        /// <summary>
        /// Tests whether a given value is valid for this validator.
        /// </summary>
        /// <param name="value">value</param>
        /// <returns>true if valid; false otherwise</returns>
        protected override ValidationResult? IsValid(object? value, ValidationContext context)
        {
            ValidationResult? retVal = ValidationResult.Success;
            String? castVal = value as String;

            if (castVal == null)
            {
                retVal = new ValidationResult("Password required.");
            }

            // Test length requirements
            if (retVal == ValidationResult.Success)
            {
                int valLen = castVal!.Length;
                if (!(MinLength <= valLen && valLen <= MaxLength))
                {
                    retVal = new ValidationResult($"Password must be between {MinLength} and {MaxLength} characters.");
                }
            }

            // Test if all characters are valid
            if (retVal == ValidationResult.Success && !_allValidCharRegex.IsMatch(castVal!))
            {
                retVal = new ValidationResult("Password contains one or more invalid characters.");
            }

            // Test if password contains at least one of each required type of character
            for (int reqIdx = 0; retVal == ValidationResult.Success && reqIdx < _charValExps.Length; ++reqIdx)
            {
                Tuple<CharacterOptions, Regex, String> curEntry = _charValExps[reqIdx];

                if (IsRequired(curEntry.Item1) && !curEntry.Item2.IsMatch(castVal!))
                {
                    retVal = new ValidationResult(curEntry.Item3);
                }
            }

            return retVal;
        }

        /// <summary>
        /// Adapter class for writing validation properties into HTML attributes.
        /// </summary>
        public class Adapter : AttributeAdapterBase<CognitoPasswordAttribute>
        {
            private const String _attrPrefix = "data-val-cognitopassword";
            private static readonly String _minLengthName;
            private static readonly String _maxLengthName;
            private static readonly String _requiredCharsName;

            /// <summary>
            /// Static constructor
            /// </summary>
            static Adapter()
            {
                _minLengthName = $"{_attrPrefix}-minlength";
                _maxLengthName = $"{_attrPrefix}-maxlength";
                _requiredCharsName = $"{_attrPrefix}-requiredchars";
            }

            /// <summary>
            /// Constructor
            /// </summary>
            /// <param name="attr">attribute</param>
            /// <param name="localizer">localizer</param>
            public Adapter(CognitoPasswordAttribute attr, IStringLocalizer? localizer) : base(attr, localizer)
            {
                // do nothing
            }

            /// <summary>
            /// Builds validation HTML attributes
            /// </summary>
            /// <param name="context">context</param>
            public override void AddValidation(ClientModelValidationContext context)
            {
                MergeAttribute(context.Attributes, "data-val", "true");
                MergeAttribute(context.Attributes, _attrPrefix, GetErrorMessage(context));

                MergeAttribute(
                    context.Attributes, 
                    _minLengthName,
                    Attribute.MinLength.ToString(CultureInfo.InvariantCulture)
                );

                MergeAttribute(
                    context.Attributes,
                    _maxLengthName,
                    Attribute.MaxLength.ToString(CultureInfo.InvariantCulture)
                );

                MergeAttribute(
                    context.Attributes,
                    _requiredCharsName,
                    ((int)Attribute.RequiredChars).ToString(CultureInfo.InvariantCulture)
                );
            }

            /// <summary>
            /// Get validation error message
            /// </summary>
            /// <param name="validationContext">context</param>
            /// <returns>error message if exists; empty string otherwise</returns>
            public override string GetErrorMessage(ModelValidationContextBase validationContext)
            {
                return Attribute.ErrorMessage != null ?
                    Attribute.ErrorMessage.ToString(CultureInfo.InvariantCulture) :
                    string.Empty;
            }
        }
    }// end class CognitoPasswordAttribute
}
