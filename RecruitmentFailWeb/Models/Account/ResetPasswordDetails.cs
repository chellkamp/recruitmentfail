using RecruitmentFailWeb.Models.DataAnnotations;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace RecruitmentFailWeb.Models.Account
{
    public class ResetPasswordDetails
    {
        [EmailAddress]
        public String Email { get; set; }

        public String Code { get; set; }

        [DisplayName("New Password")]
        [CognitoPassword(
            MinLength = 8,
            RequiredChars = CognitoPasswordAttribute.CharacterOptions.ALL)
        ]
        public String NewPassword { get; set; }

        [Display(Name = "Confirm New Password")]
        [Confirm(MatchingFieldName = "NewPassword")]
        public String NewPasswordConfirm { get; set; }

        public ResetPasswordDetails()
        {
            Email = String.Empty;
            Code = String.Empty;
            NewPassword = String.Empty;
            NewPasswordConfirm = String.Empty;
        }
    }
}
