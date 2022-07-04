

var RecruitmentFailValidation = RecruitmentFailValidation || {};

/**
 * Holds settings for password validation.
 * @class
 */
RecruitmentFailValidation.CognitoPasswordValidator = class {
    /**
     * @typedef {object} ValidationResult
     * @property {boolean} isValid - success or failure of validation
     * @property {boolean} errorMessage - reason for validation failure if isValid is false
     */

    // Constants/Fields

    static DEFAULT_MIN_LENGTH = 8;
    static DEFAULT_MAX_LENGTH = 256;

    /**
     * Available character classes for passwords.
     * @readonly
     * @enum {number}
     */
    static CharacterOptions = {
        NONE: 0x0,
        DIGIT: 0x1,
        LOWER: 0x2,
        UPPER: 0x4,
        SPECIAL: 0x8,
        ALL: 0xF
    };

    static _digitChar;
    static _lowercaseChar;
    static _uppercaseChar;
    static _specialChar;
    static _validChar;

    static _requireDigitRegex;
    static _requireLowercaseRegex;
    static _requireUppercaseRegex;
    static _requireSpecialRegex;
    static _allValidCharRegex;

    static _digitReqMsg = "Password requires at least one digit.";
    static _lowercaseReqMsg = "Password requires at least one lowercase character.";
    static _uppercaseReqMsg = "Password requires at least one uppercase character.";
    static _specialReqMsg = "Password requires at least one special character.";

    static _charValExps;

    static {
        this._digitChar = String.raw`\d`;
        this._lowercaseChar = String.raw`a-z`;
        this._uppercaseChar = String.raw`A-Z`;
        this._specialChar = String.raw` \^\$\*\.\[\]\{{\}}\(\)\?\!\@\#\%\&\/\\\,\>\<\'\:\;\|_\~\`\=\+\-\"`;
        this._validChar = `${this._digitChar}${this._lowercaseChar}${this._uppercaseChar}${this._specialChar}`;

        this._requireDigitRegex = new RegExp(`[${this._digitChar}]`);
        this._requireLowercaseRegex = new RegExp(`[${this._lowercaseChar}]`);
        this._requireUppercaseRegex = new RegExp(`[${this._uppercaseChar}]`);
        this._requireSpecialRegex = new RegExp(`[${this._specialChar}]`);
        this._allValidCharRegex = new RegExp(`^[${this._validChar}]*$`);
        this._charValExps = [
            {
                item1: this.CharacterOptions.DIGIT,
                item2: this._requireDigitRegex,
                item3: this._digitReqMsg
            },
            {
                item1: this.CharacterOptions.LOWER,
                item2: this._requireLowercaseRegex,
                item3: this._lowercaseReqMsg
            },
            {
                item1: this.CharacterOptions.UPPER,
                item2: this._requireUppercaseRegex,
                item3: this._uppercaseReqMsg
            },
            {
                item1: this.CharacterOptions.SPECIAL,
                item2: this._requireSpecialRegex,
                item3: this._specialReqMsg
            }
        ];

    }

    // Properties

    /**
      * Is at least one digit required in the password?
      * @returns {boolean}
      */
    get isDigitRequired() { return this._isRequired(this.CharacterOptions.DIGIT); }

    /**
     * Set whether a digit is required.
     * @param {boolean} value
     */
    set isDigitRequired(value) { this._setCharRequired(this.CharacterOptions.DIGIT, value); }

    /**
     * Is at least one lowercase character required?
     * @returns {boolean}
     */
    get isLowercaseRequired() { return this._isRequired(this.CharacterOptions.LOWER); }

    /**
     * Set whether a lowercase character is required.
     */
    set isLowercaseRequired(value) { this._setCharRequired(this.CharacterOptions.LOWER, value); }

    /**
     * Is at least one uppercase character required?
     * @returns {boolean}
     */
    get isUppercaseRequired() { return this._isRequired(this.CharacterOptions.UPPER); }

    /**
     * Set whether an uppercase character is required.
     */
    set isUppercaseRequired(value) { this._setCharRequired(this.CharacterOptions.UPPER, value); }

    /**
     * Is at least one special character required?
     * @returns {boolean}
     */
    get isSpecialRequired() { return this._isRequired(this.CharacterOptions.SPECIAL); }

    /**
     * Set whether a special character is required.
     */
    set isSpecialRequired(value) { this._setCharRequired(this.CharacterOptions.SPECIAL, value); }




    // Constructors

    /**
     * @constructor
     */
    constructor() {
        this.staticContext = RecruitmentFailValidation.CognitoPasswordValidator;
        this.requiredChars = this.staticContext.CharacterOptions.NONE;
        this.minLength = this.staticContext.DEFAULT_MIN_LENGTH;
        this.maxLength = this.staticContext.DEFAULT_MAX_LENGTH;
    }

    // Methods

    /**
     * Tests whether a given value is valid for this validator.
     * @param {string} value
     * @returns {ValidationResult}
     */
    isValid(value) {
        let retVal = { isValid: true, errorMessage: "" };

        if (value === null || value === "") {
            retVal.errorMessage = "Password required.";
            retVal.isValid = false;
        }

        // Test length requirements
        if (retVal.isValid) {
            let valLen = value.length;
            retVal.isValid = this.minLength <= valLen && valLen <= this.maxLength;
            if (!retVal.isValid) {
                retVal.errorMessage = `Password must be between ${this.minLength} and ${this.maxLength} characters.`;
            }
        }

        // Test if all characters are valid
        if (retVal.isValid) {
            retVal.isValid = this.staticContext._allValidCharRegex.test(value);
            if (!retVal.isValid) {
                retVal.errorMessage = "Password contains one or more invalid characters.";
            }
        }

        // Test if password contains at least one of each required type of character
        for (let reqIdx = 0; retVal.isValid && reqIdx < this.staticContext._charValExps.length; ++reqIdx)
        {
            let curEntry = this.staticContext._charValExps[reqIdx];

            if (this._isRequired(curEntry.item1)) {
                retVal.isValid = curEntry.item2.test(value);
                if (!retVal.isValid) {
                    retVal.errorMessage = curEntry.item3;
                }
            }
        }

        return retVal;
    }

    /**
      * Check whether an individual character option is required or not.
      * @param {number} option
      * @returns {boolean} true if required; false otherwise
      */
    _isRequired(option) {
        return (this.requiredChars & option) == option;
    }

    /**
     * Set a character class to be required or not required.
     * @param {number} option member of CharacterOptions enum
     * @param {boolean} value true for required; false for not required
     */
    _setCharRequired(option, value) {
        if (value) {
            this.requiredChars |= option;
        }
        else {
            this.requiredChars &= ~option;
        }
    }

};

/**
 * validate a Cognito password
 * @param {string} value
 * @param {object} element
 * @param {Array<object>} params
 */
RecruitmentFailValidation.validateCognitoPassword = function (
    value, // value of element
    element, // element being validated
    params // [minlength, maxlength, requiredChars]
) {
    let minLength = params[0];
    let maxLength = params[1];
    let requiredChars = params[2];

    let validator = new RecruitmentFailValidation.CognitoPasswordValidator();
    validator.minLength = minLength;
    validator.maxLength = maxLength;
    validator.requiredChars = requiredChars;

    let result = validator.isValid(value);

    return result.isValid;
};
