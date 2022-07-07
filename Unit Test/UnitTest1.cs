using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.ComponentModel.DataAnnotations;

using RecruitmentFailWeb.Models.DataAnnotations;

namespace UnitTest
{
    [TestClass]
    public class ValidationUnitTest
    {
        [TestMethod]
        public void TestPasswordValidation()
        {
            CognitoPasswordAttribute testAttr = new CognitoPasswordAttribute
            {
                MinLength = 8,
                MaxLength = 20,
                RequiredChars = CognitoPasswordAttribute.CharacterOptions.ALL
            };

            bool result;

            // null password
            result = testAttr.IsValid(null);
            Assert.IsFalse(result, "Null password accepted.");

            // blank password
            result = testAttr.IsValid("");
            Assert.IsFalse(result, "Empty password accepted.");

            // less than min length
            result = testAttr.IsValid("!Pass1#");
            Assert.IsFalse(result, "Password that didn't meet min length accepted.");

            // more than maximum length
            result = testAttr.IsValid("!Password#$1234567890");
            Assert.IsFalse(result, "Password that exceeded max length accepted.");

            // meets min length and all character requirements
            result = testAttr.IsValid("!Pass123");
            Assert.IsTrue(result, "Valid password rejected.");

            // missing numbers
            result = testAttr.IsValid("!Password$");
            Assert.IsFalse(result, "Password missing required number but is still accepted.");

            // missing uppercase
            result = testAttr.IsValid("!password$123");
            Assert.IsFalse(result, "Password missing required uppercase character but is still accepted.");

            // missing lowercase
            result = testAttr.IsValid("!PASSWORD$123");
            Assert.IsFalse(result, "Password missing required lowercase character but is still accepted.");

            // missing special characters
            result = testAttr.IsValid("7Password123");
            Assert.IsFalse(result, "Password missing required special character but is still accepted.");

            // includes invalid characters
            result = testAttr.IsValid("!Password\n123");
            Assert.IsFalse(result, "Password includes invalid characters but is still accepted.");


            testAttr = new CognitoPasswordAttribute
            {
                MinLength = 8,
                RequiredChars = CognitoPasswordAttribute.CharacterOptions.NONE
            };

            // missing numbers
            result = testAttr.IsValid("!Password$");
            Assert.IsTrue(
                result,
                "Password has no numbers, validation requires no numbers, but password rejected."
            );

            // missing uppercase
            result = testAttr.IsValid("!password$123");
            Assert.IsTrue(
                result,
                "Password has no uppercase characters, validation requires no uppercase characters, but password rejected."
            );

            // missing lowercase
            result = testAttr.IsValid("!PASSWORD$123");
            Assert.IsTrue(
                result,
                "Password has no lowercase characters, validation requires no lowercase characters, but password rejected."
            );

            // missing special characters
            result = testAttr.IsValid("7Password123");
            Assert.IsTrue(
                result,
                "Password has no special characters, validation requires no special characters, but password rejected."
            );

            testAttr = new CognitoPasswordAttribute
            {
                MinLength = 8,
                RequiredChars = CognitoPasswordAttribute.CharacterOptions.LOWER | CognitoPasswordAttribute.CharacterOptions.DIGIT
            };

            // missing numbers
            result = testAttr.IsValid("!Password$");
            Assert.IsFalse(result, "Password missing required number but is still accepted.");

            // missing uppercase
            result = testAttr.IsValid("!password$123");
            Assert.IsTrue(
                result,
                "Password has no uppercase characters, validation requires no uppercase characters, but password rejected."
            );

            // missing lowercase
            result = testAttr.IsValid("!PASSWORD$123");
            Assert.IsFalse(result, "Password missing required lowercase character but is still accepted.");

            // missing special characters
            result = testAttr.IsValid("7Password123");
            Assert.IsTrue(
                result,
                "Password has no special characters, validation requires no special characters, but password rejected."
            );

        }

        [TestMethod]
        public void TestConfirmValidation()
        {
            string passToMatch = "P@$$word123";

            object testModel = new
            {
                Password = passToMatch
            };

            ValidationContext context = new ValidationContext(testModel);

            // nominal case.  value matches Password field
            ConfirmAttribute confirm = new ConfirmAttribute { MatchingFieldName = "Password" };
            ValidationResult? result = confirm.GetValidationResult(passToMatch, context);
            Assert.AreEqual(ValidationResult.Success, result);

            // Password field is different
            result = confirm.GetValidationResult("P@$$word321", context);
            Assert.AreNotEqual(ValidationResult.Success, result);

            // no "Password" field to speak of.
            testModel = new { password = passToMatch };
            context = new ValidationContext(testModel);
            result = confirm.GetValidationResult(passToMatch, context);
            Assert.AreNotEqual(ValidationResult.Success, result);

            confirm.MatchingFieldName = "password";
            result = confirm.GetValidationResult(passToMatch, context);
            Assert.AreEqual(ValidationResult.Success, result);

        }
    }
}