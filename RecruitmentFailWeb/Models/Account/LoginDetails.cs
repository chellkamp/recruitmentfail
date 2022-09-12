using System.ComponentModel.DataAnnotations;

namespace RecruitmentFailWeb.Models.Account
{
    public class LoginDetails
    {
        [EmailAddress]
        public String Email { get; set; }

        [Required(ErrorMessage = "Password required")]
        public String Password { get; set; }

        public String? ReturnUrl { get; set; }

        public LoginDetails()
        {
            Email = "";
            Password = "";
            ReturnUrl = null;
        }
    }
}
