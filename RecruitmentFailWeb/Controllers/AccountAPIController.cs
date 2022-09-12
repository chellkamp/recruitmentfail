using Amazon.AspNetCore.Identity.Cognito;
using Amazon.Extensions.CognitoAuthentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;


using RecruitmentFailWeb.Models.Account;
using RecruitmentFailWeb.Util;
using System.Security.Claims;

namespace RecruitmentFailWeb.Controllers
{
    [Route("api/Account")]
    [ApiController]
    public class AccountAPIController : ControllerBase
    {
        private ILogger<AccountAPIController> _logger;
        private CognitoUserPool _userPool;
        private CognitoUserManager<CognitoUser> _userManager;
        private SignInManager<CognitoUser> _signInManager;

        public AccountAPIController(
            ILogger<AccountAPIController> logger,
            CognitoUserPool userPool,
            UserManager<CognitoUser> userManager,
            SignInManager<CognitoUser> signInManager
        )
        {
            _logger = logger;
            _userPool = userPool;
            _userManager = (CognitoUserManager<CognitoUser>)userManager;
            _signInManager = signInManager;
        }

        
        [Authorize]
        [HttpPost]
        [Route("ChangePassword")]
        public async Task ChangePassword([FromForm]ChangePasswordDetails details)
        {
            if (!ModelState.IsValid)
            {
                String error = ModelState.Values.FirstOrDefault()?.Errors.FirstOrDefault()?.ErrorMessage ?? "Invalid input";
                _logger.LogInformation("ModelState invalid.", ModelState);
                throw new ReasonException(error);
            }

            String? email = User?.Claims?.FirstOrDefault(c => c.Type == ClaimTypes.Email)?.Value;
            if (String.IsNullOrEmpty(email))
            {
                _logger.LogInformation("User does not appear to be logged in.");
                throw new ReasonException("Error finding user in system.");
            }

            CognitoUser? user = await _userPool.FindByIdAsync(email);
            if (user == null)
            {
                _logger.LogInformation($"Unable to find user for email '{email}'");
                throw new ReasonException("Error finding user in system.");
            }

            IdentityResult? result = await _userManager.ChangePasswordAsync(user!, details.OldPassword, details.NewPassword);

            if (result == null)
            {
                _logger.LogError("Call to ChangePasswordAsync() returned null IdentityResult.");
                throw new ReasonException("Failed to change password.");
            }

            if (!result!.Succeeded)
            {
                String? error = String.Join(";\n", result.Errors.Select(e => e.Description).ToArray());
                _logger.LogInformation(error);
                throw new ReasonException("Failed to change password.");
            }
        }

        [HttpPost]
        [Route("RequestPasswordReset")]
        public async Task RequestPasswordReset([FromForm]RequestPasswordResetDetails details)
        {
            if (!ModelState.IsValid)
            {
                String error = ModelState.Values.FirstOrDefault()?.Errors.FirstOrDefault()?.ErrorMessage ?? "Invalid input";
                _logger.LogInformation("ModelState invalid.", ModelState);
                throw new ReasonException(error);
            }

            String email = details.Email;

            CognitoUser? user = await _userManager.FindByIdAsync(email);
            if (user == null)
            {
                _logger.LogInformation($"Unable to find user for email '{email}'.");
                throw new ReasonException($"Cannot find user for email address '{email}'.");
            }

            IdentityResult? result = await _userManager.ResetPasswordAsync(user);
            if (result == null)
            {
                _logger.LogError("Call to ResetPasswordAsync() returned null IdentityResult.");
                throw new ReasonException("Failed to process reset request.");
            }

            if (!result!.Succeeded)
            {
                String? error = String.Join(";\n", result.Errors.Select(e => e.Description).ToArray());
                _logger.LogInformation(error);
                throw new ReasonException("Failed to process reset request.");
            }
        }

        [HttpPost]
        [Route("ResetPassword")]
        public async Task ResetPassword([FromForm]ResetPasswordDetails details)
        {
            if (!ModelState.IsValid)
            {
                String error = ModelState.Values.FirstOrDefault()?.Errors.FirstOrDefault()?.ErrorMessage ?? "Invalid input";
                _logger.LogInformation("ModelState invalid.", ModelState);
                throw new ReasonException(error);
            }

            String email = details.Email;

            CognitoUser? user = await _userManager.FindByIdAsync(email);
            if (user == null)
            {
                _logger.LogInformation($"Unable to find user for email '{email}'.");
                throw new ReasonException($"Cannot find user for email address '{email}'.");
            }

            IdentityResult? result = await _userManager.ResetPasswordAsync(user, details.Code, details.NewPassword);
            if (result == null)
            {
                _logger.LogError("Call to ResetPasswordAsync() returned null IdentityResult.");
                throw new ReasonException("Failed to process password reset.");
            }

            if (!result!.Succeeded)
            {
                String? error = String.Join(";\n", result.Errors.Select(e => e.Description).ToArray());
                _logger.LogInformation(error);
                throw new ReasonException("Failed to reset password.");
            }
        }
    }
}
