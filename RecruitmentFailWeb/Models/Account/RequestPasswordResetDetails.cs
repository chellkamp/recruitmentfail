using System.ComponentModel.DataAnnotations;

namespace RecruitmentFailWeb.Models.Account
{
    public class RequestPasswordResetDetails
    {
        [EmailAddress]
        public String Email { get; set; }

        public RequestPasswordResetDetails()
        {
            Email = String.Empty;
        }
    }
}
