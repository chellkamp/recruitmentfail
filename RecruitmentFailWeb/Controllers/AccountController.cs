using Microsoft.AspNetCore.Mvc;

namespace RecruitmentFailWeb.Controllers
{
    public class AccountController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }

        public IActionResult Create()
        {
            return View(new Models.Account.NewUserDetails());
        }
    }
}
