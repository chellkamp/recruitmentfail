using System.ComponentModel.DataAnnotations;

namespace RecruitmentFailWeb.Models.Account
{
    public class VerificationDetails
    {
        [EmailAddress]
        public string Email { get; set; }

        public bool IsVerified { get; set; }

        public VerificationDetails()
        {
            Email = "";
            IsVerified = false;
        }

    }
}
