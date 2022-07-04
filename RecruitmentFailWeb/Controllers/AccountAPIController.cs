using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace RecruitmentFailWeb.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AccountAPIController : ControllerBase
    {
        [HttpPost]
        public JsonResult AttemptCreate(String username, String password)
        {
            return new JsonResult(new { success = true });
        }
    }
}
