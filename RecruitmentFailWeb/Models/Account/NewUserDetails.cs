using System.ComponentModel.DataAnnotations;

using RecruitmentFailWeb.Models.DataAnnotations;

namespace RecruitmentFailWeb.Models.Account
{

    public class NewUserDetails : IValidatableObject
    {
        [EmailAddress]
        public String Email { get; set; }

        [CognitoPassword(
            MinLength = 8,
            RequiredChars = CognitoPasswordAttribute.CharacterOptions.ALL)
        ]
        public String Password { get; set; }

        [Display(Name = "Confirm Password")]
        public String PasswordConfirm { get; set; }

        public NewUserDetails()
        {
            Email = "";
            Password = "";
            PasswordConfirm = "";
        }

        /*
         * Performs cross-field validation
         */
        public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
        {
            if (!String.Equals(PasswordConfirm, Password))
            {
                yield return new ValidationResult("Passwords must match.", new[] { nameof(PasswordConfirm) });
            }
        }
    }
}
