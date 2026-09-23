/**
 * Records NavigationMixin calls for Jest. Pattern from Salesforce LWC recipes.
 */
export const CurrentPageReference = jest.fn();

let _pageReference;
let _replace;

const Navigate = Symbol("Navigate");
const GenerateUrl = Symbol("GenerateUrl");

export const NavigationMixin = (Base) => {
    return class extends Base {
        [Navigate](pageReference, replace) {
            _pageReference = pageReference;
            _replace = replace;
        }
        [GenerateUrl]() {
            return Promise.resolve("https://www.example.com");
        }
    };
};
NavigationMixin.Navigate = Navigate;
NavigationMixin.GenerateUrl = GenerateUrl;

export const getNavigateCalledWith = () => {
    return {
        pageReference: _pageReference,
        replace: _replace
    };
};
