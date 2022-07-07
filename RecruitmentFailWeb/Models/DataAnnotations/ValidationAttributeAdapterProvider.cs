using MicrosoftAnnotations = Microsoft.AspNetCore.Mvc.DataAnnotations;
using Microsoft.Extensions.Localization;
using System.ComponentModel.DataAnnotations;

namespace RecruitmentFailWeb.Models.DataAnnotations
{
    /// <summary>
    /// Used to hook up any custom validation attributes to the web project.
    /// </summary>
    public class ValidationAttributeAdapterProvider : MicrosoftAnnotations.IValidationAttributeAdapterProvider
    {
        private readonly MicrosoftAnnotations.IValidationAttributeAdapterProvider _baseProvider = new MicrosoftAnnotations.ValidationAttributeAdapterProvider();

        /// <summary>
        /// Get the proper adapter for the attribute
        /// </summary>
        /// <param name="attribute">attribute</param>
        /// <param name="stringLocalizer">localizer</param>
        /// <returns>adapter</returns>
        /// <exception cref="NotImplementedException"></exception>
        public MicrosoftAnnotations.IAttributeAdapter? GetAttributeAdapter(ValidationAttribute attribute, IStringLocalizer? stringLocalizer)
        {
            MicrosoftAnnotations.IAttributeAdapter? retVal = null;

            if (attribute is CognitoPasswordAttribute)
            {
                retVal = new CognitoPasswordAttribute.Adapter((CognitoPasswordAttribute)attribute, stringLocalizer);
            }
            else if (attribute is ConfirmAttribute)
            {
                retVal = new ConfirmAttribute.Adapter((ConfirmAttribute)attribute, stringLocalizer);
            }
            return retVal;
        }
    }
}
