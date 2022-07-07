using Microsoft.AspNetCore.Mvc.DataAnnotations;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;
using Microsoft.Extensions.Localization;
using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Reflection;

namespace RecruitmentFailWeb.Models.DataAnnotations
{
    public class ConfirmAttribute : ValidationAttribute
    {
        private readonly string DEFAULT_MATCHING_FIELD = "Password";
        /// <summary>
        /// Name of field in validation context object to match against
        /// </summary>
        public string MatchingFieldName { get; set; }

        /// <summary>
        /// Constructor
        /// </summary>
        public ConfirmAttribute()
        {
            MatchingFieldName = DEFAULT_MATCHING_FIELD;
        }

        protected override ValidationResult? IsValid(object? value, ValidationContext validationContext)
        {
            ValidationResult? retVal = ValidationResult.Success;

            object obj = validationContext.ObjectInstance;
            Type t = obj.GetType();
            PropertyInfo? propInfo = t.GetProperty(MatchingFieldName, typeof(string));

            if (propInfo == null)
            {
                retVal = new ValidationResult("Matching Field does not exist.");
            }

            MethodInfo? m = null;
            if (retVal == ValidationResult.Success)
            {
                m = propInfo!.GetGetMethod();
                if (m == null)
                {
                    retVal = new ValidationResult("Matching Field cannot be accessed.");
                }
            }

            if (retVal == ValidationResult.Success)
            {
                string? matchingValue = (string?)(m!.Invoke(obj, null));
                if (!Equals(matchingValue, value))
                {
                    retVal = new ValidationResult($"Does not match {MatchingFieldName}.");
                }
            }

            return retVal;
        }

        public class Adapter : AttributeAdapterBase<ConfirmAttribute>
        {
            private const string _attrPrefix = "data-val-confirm";
            private static readonly string _matchingFieldNameName;

            // Constructors

            /// <summary>
            /// Static constructor
            /// </summary>
            static Adapter()
            {
                _matchingFieldNameName = $"{_attrPrefix}-matchingfieldname";
            }

            /// <summary>
            /// Constructor
            /// </summary>
            /// <param name="attr">attribute</param>
            /// <param name="localizer">localizer</param>
            public Adapter(ConfirmAttribute attr, IStringLocalizer? localizer) : base(attr, localizer)
            {
                // do nothing
            }

            /// <summary>
            /// Builds validation HTML attributes
            /// </summary>
            /// <param name="context">context</param>
            public override void AddValidation(ClientModelValidationContext context)
            {
                MergeAttribute(context.Attributes, "data-val", "true");
                MergeAttribute(context.Attributes, _attrPrefix, GetErrorMessage(context));

                MergeAttribute(
                    context.Attributes,
                    _matchingFieldNameName,
                    Attribute.MatchingFieldName.ToString(CultureInfo.InvariantCulture)
                );
            }


            /// <summary>
            /// Get validation error message
            /// </summary>
            /// <param name="validationContext">context</param>
            /// <returns>error message if exists; empty string otherwise</returns>
            public override string GetErrorMessage(ModelValidationContextBase validationContext)
            {
                return Attribute.ErrorMessage != null ?
                    Attribute.ErrorMessage.ToString(CultureInfo.InvariantCulture) :
                    string.Empty;
            }
        }
    }
}
