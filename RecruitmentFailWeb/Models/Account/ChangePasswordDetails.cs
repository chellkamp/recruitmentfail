using RecruitmentFailWeb.Models.DataAnnotations;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace RecruitmentFailWeb.Models.Account
{
    public class ChangePasswordDetails
    {
        [DisplayName("Your Current Password")]
        [Required(ErrorMessage = "Password required")]
        public String OldPassword { get; set; }

        [DisplayName("New Password")]
        [CognitoPassword(
            MinLength = 8,
            RequiredChars = CognitoPasswordAttribute.CharacterOptions.ALL)
        ]
        public String NewPassword { get; set; }

        [Display(Name = "Confirm New Password")]
        [Confirm(MatchingFieldName = "NewPassword")]
        public String NewPasswordConfirm { get; set; }

        /// <summary>
        /// Constructor
        /// </summary>
        public ChangePasswordDetails()
        {
            OldPassword = String.Empty;
            NewPassword = String.Empty;
            NewPasswordConfirm = String.Empty;
        }
    }
}
