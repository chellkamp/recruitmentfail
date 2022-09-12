using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

using Amazon.AspNetCore.Identity.Cognito;
using Amazon.CognitoIdentityProvider.Model;
using Amazon.Extensions.CognitoAuthentication;

using RecruitmentFailWeb.Models.Account;
using Microsoft.AspNetCore.Authentication;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;

namespace RecruitmentFailWeb.Controllers
{
    public class AccountController : Controller
    {
        private const String TEMP_EMAIL_KEY = "TempEmail";

        private ILogger<AccountController> _logger;
        private CognitoUserPool _userPool;
        private CognitoUserManager<CognitoUser> _userManager;
        private SignInManager<CognitoUser> _signInManager;

        public AccountController(
            ILogger<AccountController> logger,
            CognitoUserPool userPool,
            UserManager<CognitoUser> userManager,
            SignInManager<CognitoUser> signInManager)
        {
            _logger = logger;
            _userPool = userPool;
            _userManager = (CognitoUserManager<CognitoUser>)userManager;
            _signInManager = signInManager;
        }

        public IActionResult Index()
        {
            return View();
        }

        [HttpGet]
        [ActionName("Create")]
        public IActionResult CreateGet()
        {
            return View(new NewUserDetails());
        }

        [HttpPost]
        [ActionName("Create")]
        public async Task<IActionResult> CreatePost([FromForm] NewUserDetails details)
        {
            if (!ModelState.IsValid)
            {
                return View(details);
            }
            
            CognitoUser user = _userPool.GetUser(details.Email);
            user.Attributes.Add(CognitoAttribute.Email.AttributeName, details.Email);

            IdentityResult createResult = await _userManager.CreateAsync(user, details.Password);

            if (!createResult.Succeeded)
            {
                foreach (IdentityError error in createResult.Errors)
                {
                    ModelState.AddModelError(String.Empty, error.Description);
                }
                return View(details);
            }

            HttpContext.Session.SetString(TEMP_EMAIL_KEY, details.Email);

            return RedirectToAction("ConfirmEmail");
        }

        [HttpGet]
        [ActionName("ConfirmEmail")]
        public async Task<IActionResult> ConfirmEmailGet()
        {
            VerificationDetails details = new VerificationDetails();

            // First see if a valid user is already logged in
            details.Email = User?.Claims?.FirstOrDefault(c => c.Type == ClaimTypes.Email)?.Value ?? String.Empty;
            details.IsVerified = User?.Claims?.FirstOrDefault(c => c.Type == "email_verified")?.Equals("true") ?? false;

            if (details.Email == String.Empty)
            {
                // try session state
                details.Email = HttpContext.Session.GetString(TEMP_EMAIL_KEY) ?? String.Empty;
                if (details.Email != String.Empty)
                {
                    CognitoUser? user = await _userPool.FindByIdAsync(details.Email);
                    details.IsVerified = user?.Attributes?.FirstOrDefault(a => a.Key == "email_verified").Value == "true";
                }
            }

            if (details.Email == String.Empty)
            {
                ModelState.AddModelError(String.Empty, "Data for this page has expired.  Please log in again.");
            }

            return View(details);
        }

        [HttpPost]
        [ActionName("ConfirmEmail")]
        public async Task<IActionResult> ConfirmEmailPost()
        {

            VerificationDetails details = new VerificationDetails();
            CognitoUser? user = null;

            // First see if a valid user is already logged in
            details.Email = User?.Claims?.FirstOrDefault(c => c.Type == ClaimTypes.Email)?.Value ?? String.Empty;

            if (details.Email == String.Empty)
            {
                // try session state
                details.Email = HttpContext.Session.GetString(TEMP_EMAIL_KEY) ?? String.Empty;
            }

            if (details.Email == String.Empty)
            {
                ModelState.AddModelError(String.Empty, "Data for this page has expired.  Please log in again.");
            }
            
            if (ModelState.IsValid)
            {
                user = await _userPool.FindByIdAsync(details.Email);
                details.IsVerified = user?.Attributes?.FirstOrDefault(a => a.Key == "email_verified").Value == "true";

                if (user == null)
                {
                    ModelState.AddModelError(String.Empty, $"User for {details.Email} not found.");
                }
            }

            if (ModelState.IsValid)
            {
                IdentityResult result = await _userManager.ResendSignupConfirmationCodeAsync(user!);

                if (!result.Succeeded)
                {
                    ModelState.AddModelError(String.Empty, "Failed to resend confirmation email.");
                }
            }

            return View(details);
        }

        [HttpGet]
        [ActionName("Login")]
        public IActionResult LoginGet()
        {
            LoginDetails details = new LoginDetails();
            return View(details);
        }

        [HttpPost]
        [ActionName("Login")]
        public async Task<IActionResult> LoginPost([FromForm] LoginDetails details)
        {
            if (!ModelState.IsValid)
            {
                return View(details);
            }

            if (String.IsNullOrEmpty(details.ReturnUrl))
            {
                details.ReturnUrl = Url.Content("~/");
            }

            Microsoft.AspNetCore.Identity.SignInResult? result = null;
            try
            {
                result = await _signInManager.PasswordSignInAsync(details.Email, details.Password, false, false);
            }
            catch(UserNotConfirmedException ex)
            {
                CognitoUser? user = await _userManager.FindByNameAsync(details.Email);
                if (user != null)
                {
                    HttpContext.Session.SetString(TEMP_EMAIL_KEY, details.Email);
                }
                return RedirectToAction("ConfirmEmail");
            }
            

            if (result!.Succeeded)
            {
                return LocalRedirect(details.ReturnUrl);
            } else if (result!.IsCognitoSignInResult())
            {
                CognitoSignInResult castResult = (CognitoSignInResult)result!;
                if (castResult.RequiresPasswordChange)
                {
                    return RedirectToAction("ChangePassword");
                } else if (castResult.RequiresPasswordReset)
                {
                    return RedirectToAction("RequestPasswordReset");
                }
            }

            ModelState.AddModelError(String.Empty, "Invalid login");
            return View(details);
        }

        [Authorize]
        [HttpGet]
        [ActionName("ChangePassword")]
        public IActionResult ChangePasswordGet()
        {
            return View(new ChangePasswordDetails());
        }

        [HttpGet]
        [ActionName("ResetPassword")]
        public IActionResult ResetPasswordGet()
        {
            return View(new RequestPasswordResetDetails());
        }

    }
}
